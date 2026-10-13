import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../domain/vpn_state.dart';
import '../../logs/domain/core_log_line.dart';
import 'clash_api_client.dart';
import 'vpn_platform.dart';

/// Runs `sing-box.exe` (shipped in `core\` next to the app executable) as a
/// child process with a wintun TUN inbound. TUN needs administrator rights;
/// the runner manifest requests elevation at launch.
class WindowsVpnPlatform implements VpnPlatform {
  WindowsVpnPlatform({
    String? coreExecutable,
    Future<Directory> Function()? dataDirectory,
    Future<bool> Function()? elevationCheck,
  }) : _coreExecutableOverride = coreExecutable,
       _dataDirectory = dataDirectory ?? getApplicationSupportDirectory,
       _elevationCheck = elevationCheck ?? isElevated;

  static const _startupTimeout = Duration(seconds: 20);
  static const _logTail = 30;
  static const _historySize = 500;

  final String? _coreExecutableOverride;
  final Future<Directory> Function() _dataDirectory;
  final Future<bool> Function() _elevationCheck;
  final _events = StreamController<VpnPlatformEvent>.broadcast();
  final _recentLines = <String>[];

  /// Log of the core for the logs page, kept across restarts.
  final _history = <String>[];

  Process? _process;
  bool _stopRequested = false;
  Process? _tester;

  @override
  CorePlatform get corePlatform => CorePlatform.windows;

  @override
  Stream<VpnPlatformEvent> get events => _events.stream;

  String get coreExecutable =>
      _coreExecutableOverride ??
      '${File(Platform.resolvedExecutable).parent.path}\\core\\sing-box.exe';

  @override
  Future<String?> workingDirectory() async {
    final dir = Directory(
      '${(await _dataDirectory()).path}${Platform.pathSeparator}core',
    );
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<void> start(VpnStartRequest request) async {
    if (_process != null) await stop();
    final exe = File(coreExecutable);
    if (!exe.existsSync()) {
      throw VpnError(VpnErrorCode.coreMissing, exe.path);
    }
    if (!await _elevationCheck()) {
      throw const VpnError(VpnErrorCode.adminRequired);
    }

    final workDir = (await workingDirectory())!;
    await _killOrphan(workDir);

    _recentLines.clear();
    _stopRequested = false;
    final process = await _runWithConfig(exe, request.configJson, workDir);
    _process = process;
    await File('$workDir${Platform.pathSeparator}core.pid')
        .writeAsString('${process.pid}');

    for (final stream in [process.stdout, process.stderr]) {
      stream
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _recentLines.add(line);
            if (_recentLines.length > _logTail) _recentLines.removeAt(0);
            _history.add(line);
            if (_history.length > _historySize) _history.removeAt(0);
            _events.add(VpnLogLine(line));
          });
    }
    unawaited(
      process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        final error = _stopRequested || code == 0
            ? null
            : VpnError(VpnErrorCode.coreExited, _lastError());
        _events.add(VpnStopped(error));
      }),
    );
    unawaited(_waitUntilReady(process, request.configJson));
  }

  /// The core is "connected" once its Clash API answers.
  Future<void> _waitUntilReady(Process process, String configJson) async {
    final api = ClashApiClient.optionsFromConfig(configJson);
    final deadline = DateTime.now().add(_startupTimeout);
    while (identical(_process, process) && DateTime.now().isBefore(deadline)) {
      if (api == null || await ClashApiClient(api).ping()) {
        if (identical(_process, process)) _events.add(const VpnStarted());
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (identical(_process, process)) {
      _recentLines.add(
        'core did not become ready in ${_startupTimeout.inSeconds}s',
      );
      process.kill();
    }
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      _events.add(const VpnStopped());
      return;
    }
    _stopRequested = true;
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
  }

  @override
  Future<bool> isRunning() async => _process != null;

  @override
  Future<String?> coreVersion() async {
    final exe = File(coreExecutable);
    if (!exe.existsSync()) return null;
    try {
      final result = await Process.run(exe.path, ['version']);
      final firstLine = (result.stdout as String).split('\n').first.trim();
      return firstLine.replaceFirst('sing-box version ', '');
    } on ProcessException {
      return null;
    }
  }

  @override
  Future<String?> checkConfig(String configJson) async {
    final exe = File(coreExecutable);
    if (!exe.existsSync()) return 'core not found: ${exe.path}';
    final process = await Process.start(exe.path, [
      'check',
      '-c',
      'stdin',
      '--disable-color',
    ]);
    final stdout = process.stdout.transform(const SystemEncoding().decoder);
    final stderr = process.stderr.transform(const SystemEncoding().decoder);
    final outputs = Future.wait([stderr.join(), stdout.join()]);
    process.stdin.write(configJson);
    await process.stdin.close();
    final code = await process.exitCode;
    if (code == 0) return null;
    final output = (await outputs).join('\n').trim();
    return output.isEmpty ? 'exit code $code' : output;
  }

  /// Starts `sing-box run` with [configJson] on its standard input. The
  /// config never touches the disk: it holds the servers' secrets, and a
  /// file in the user's profile could be swapped by any program the user
  /// runs before the (elevated) core reads it.
  Future<Process> _runWithConfig(
    File exe,
    String configJson,
    String workDir,
  ) async {
    final process = await Process.start(exe.path, [
      'run',
      '-c',
      'stdin',
      '-D',
      workDir,
      '--disable-color',
    ], workingDirectory: workDir);
    process.stdin.write(configJson);
    await process.stdin.close();
    return process;
  }

  /// The tester is a second sing-box process without TUN (elevated like
  /// the app itself). `route.auto_detect_interface` in its config binds its
  /// sockets to the physical interface, so a running tunnel does not wrap
  /// measurements.
  @override
  Future<void> startTester(String configJson) async {
    await stopTester();
    final exe = File(coreExecutable);
    if (!exe.existsSync()) {
      throw VpnError(VpnErrorCode.coreMissing, exe.path);
    }
    final dir = await _testerDirectory();
    final process = await _runWithConfig(exe, configJson, dir.path);
    _tester = process;
    final output = <String>[];
    for (final stream in [process.stdout, process.stderr]) {
      stream
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            output.add(line);
            if (output.length > _logTail) output.removeAt(0);
          });
    }
    var exited = false;
    unawaited(process.exitCode.then((_) => exited = true));

    final api = ClashApiClient.optionsFromConfig(configJson);
    final deadline = DateTime.now().add(_startupTimeout);
    while (!exited && DateTime.now().isBefore(deadline)) {
      if (api == null || await ClashApiClient(api).ping()) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await stopTester();
    // Give the output listeners a moment to drain the last lines.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw VpnError(
      VpnErrorCode.coreExited,
      output.isEmpty ? 'tester did not start' : output.join('\n'),
    );
  }

  @override
  Stream<CoreLogLine> coreLogs() async* {
    for (final line in List.of(_history)) {
      yield CoreLogLine.parse(line);
    }
    yield* _events.stream
        .where((e) => e is VpnLogLine)
        .map((e) => CoreLogLine.parse((e as VpnLogLine).line));
  }

  @override
  Future<void> stopTester() async {
    final tester = _tester;
    _tester = null;
    if (tester == null) return;
    tester.kill();
    await tester.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
  }

  Future<Directory> _testerDirectory() async {
    final dir = Directory(
      '${(await _dataDirectory()).path}${Platform.pathSeparator}tester',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// `net session` only succeeds in an elevated process.
  static Future<bool> isElevated() async {
    try {
      final result = await Process.run(systemTool('net.exe'), ['session']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// A Windows tool by its full path. A bare name would also be looked up
  /// next to the app, where (in an unzipped folder) anyone could drop a
  /// program the elevated app then runs.
  static String systemTool(String name) =>
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}'
      '\\System32\\$name';

  /// Kills a core left running by a previous crashed session, which would
  /// otherwise keep the TUN interface and ports busy.
  Future<void> _killOrphan(String workDir) async {
    if (!Platform.isWindows) return;
    final pidFile = File('$workDir${Platform.pathSeparator}core.pid');
    if (!pidFile.existsSync()) return;
    final pid = int.tryParse((await pidFile.readAsString()).trim());
    await pidFile.delete();
    if (pid == null) return;
    final list = await Process.run(systemTool('tasklist.exe'), [
      '/FI',
      'PID eq $pid',
      '/FO',
      'CSV',
      '/NH',
    ]);
    if ((list.stdout as String).toLowerCase().contains('sing-box.exe')) {
      await Process.run(systemTool('taskkill.exe'), ['/PID', '$pid', '/F']);
    }
  }

  String _lastError() {
    final errors = _recentLines.where(
      (l) => l.contains('FATAL') || l.contains('ERROR') || l.contains('error'),
    );
    return (errors.isNotEmpty
            ? errors.last
            : (_recentLines.isEmpty ? '' : _recentLines.last))
        .trim();
  }
}

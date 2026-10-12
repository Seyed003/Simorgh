import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../domain/vpn_state.dart';
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

  final String? _coreExecutableOverride;
  final Future<Directory> Function() _dataDirectory;
  final Future<bool> Function() _elevationCheck;
  final _events = StreamController<VpnPlatformEvent>.broadcast();
  final _recentLines = <String>[];

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
    final configFile = File('$workDir${Platform.pathSeparator}config.json');
    await configFile.writeAsString(request.configJson, flush: true);

    _recentLines.clear();
    _stopRequested = false;
    final process = await Process.start(exe.path, [
      'run',
      '-c',
      configFile.path,
      '-D',
      workDir,
      '--disable-color',
    ], workingDirectory: workDir);
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
    final dir = await _testerDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}check.json');
    await file.writeAsString(configJson, flush: true);
    final result = await Process.run(exe.path, [
      'check',
      '-c',
      file.path,
      '--disable-color',
    ]);
    if (result.exitCode == 0) return null;
    final output = '${result.stderr}\n${result.stdout}'.trim();
    return output.isEmpty ? 'exit code ${result.exitCode}' : output;
  }

  /// The tester is a second, unprivileged sing-box process without TUN.
  /// `route.auto_detect_interface` in its config binds its sockets to the
  /// physical interface, so a running tunnel does not wrap measurements.
  @override
  Future<void> startTester(String configJson) async {
    await stopTester();
    final exe = File(coreExecutable);
    if (!exe.existsSync()) {
      throw VpnError(VpnErrorCode.coreMissing, exe.path);
    }
    final dir = await _testerDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}tester.json');
    await file.writeAsString(configJson, flush: true);
    final process = await Process.start(exe.path, [
      'run',
      '-c',
      file.path,
      '-D',
      dir.path,
      '--disable-color',
    ], workingDirectory: dir.path);
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
      final result = await Process.run('net', ['session'], runInShell: true);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Kills a core left running by a previous crashed session, which would
  /// otherwise keep the TUN interface and ports busy.
  Future<void> _killOrphan(String workDir) async {
    if (!Platform.isWindows) return;
    final pidFile = File('$workDir${Platform.pathSeparator}core.pid');
    if (!pidFile.existsSync()) return;
    final pid = int.tryParse((await pidFile.readAsString()).trim());
    await pidFile.delete();
    if (pid == null) return;
    final list = await Process.run('tasklist', [
      '/FI',
      'PID eq $pid',
      '/FO',
      'CSV',
      '/NH',
    ]);
    if ((list.stdout as String).toLowerCase().contains('sing-box.exe')) {
      await Process.run('taskkill', ['/PID', '$pid', '/F']);
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

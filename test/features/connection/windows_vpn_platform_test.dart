import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/data/windows_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

void main() {
  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('core-process'),
  );
  tearDown(() async => dir.delete(recursive: true));

  WindowsVpnPlatform platform({String? exe, bool elevated = true}) =>
      WindowsVpnPlatform(
        coreExecutable: exe ?? '${dir.path}/missing.exe',
        dataDirectory: () async => dir,
        elevationCheck: () async => elevated,
      );

  const request = VpnStartRequest(configJson: '{}', profileName: 'x');

  test('missing core binary', () async {
    expect(
      () => platform().start(request),
      throwsA(
        isA<VpnError>().having((e) => e.code, 'code', VpnErrorCode.coreMissing),
      ),
    );
  });

  test('requires elevation', () async {
    final exe = File('${dir.path}/sing-box')..writeAsStringSync('');
    expect(
      () => platform(exe: exe.path, elevated: false).start(request),
      throwsA(
        isA<VpnError>().having(
          (e) => e.code,
          'code',
          VpnErrorCode.adminRequired,
        ),
      ),
    );
  });

  group('with a real sing-box core', () {
    final binary = Platform.environment['SING_BOX_BIN'];
    final skip = binary == null || !File(binary).existsSync()
        ? 'set SING_BOX_BIN to a sing-box executable to run'
        : null;

    String config({required int mixedPort, required int apiPort}) =>
        SingBoxConfigBuilder(
          // `other` = no TUN, so the test needs no privileges.
          options: CoreOptions(mixedPort: mixedPort),
          platform: CorePlatform.other,
          clashApi: ClashApiOptions(port: apiPort, secret: 's'),
        ).buildJson(LinkParser.parse(trojanBare));

    test(
      'starts, reports ready, writes logs and stops cleanly',
      skip: skip,
      () async {
        final p = platform(exe: binary);
        final events = <VpnPlatformEvent>[];
        final sub = p.events.listen(events.add);
        addTearDown(sub.cancel);

        await p.start(
          VpnStartRequest(
            configJson: config(
              mixedPort: await _freePort(),
              apiPort: await _freePort(),
            ),
            profileName: 'bare',
          ),
        );
        await p.events
            .firstWhere((e) => e is VpnStarted)
            .timeout(const Duration(seconds: 15));
        expect(await p.isRunning(), isTrue);
        // The config (with the servers' secrets) goes in on stdin, never
        // to a file another program could read or swap.
        expect(
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json')),
          isEmpty,
        );
        expect(await p.coreVersion(), isNotEmpty);

        final stopped = p.events.firstWhere((e) => e is VpnStopped);
        await p.stop();
        final event =
            await stopped.timeout(const Duration(seconds: 10)) as VpnStopped;
        expect(event.error, isNull);
        expect(await p.isRunning(), isFalse);
      },
    );

    test('checks configs through stdin', skip: skip, () async {
      final p = platform(exe: binary);
      expect(
        await p.checkConfig(config(mixedPort: 20808, apiPort: 20809)),
        isNull,
      );
      expect(
        await p.checkConfig('{"outbounds":[{"type":"no-such-type"}]}'),
        contains('no-such-type'),
      );
    });

    test('a core that fails to start reports coreExited', skip: skip, () async {
      final p = platform(exe: binary);
      final stopped = p.events.firstWhere((e) => e is VpnStopped);
      await p.start(
        const VpnStartRequest(
          configJson: '{"outbounds":[{"type":"no-such-type","tag":"x"}]}',
          profileName: 'bad',
        ),
      );
      final event =
          await stopped.timeout(const Duration(seconds: 10)) as VpnStopped;
      expect(event.error!.code, VpnErrorCode.coreExited);
      expect(event.error!.message, contains('no-such-type'));
    });
  });
}

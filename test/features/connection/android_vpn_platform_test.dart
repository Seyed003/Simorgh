import 'package:aghelan_ghiamat/features/connection/data/android_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/data/vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.aghelan.ghiamat/vpn');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('parses service events', () {
    expect(
      AndroidVpnPlatform.parseEvent({'status': 'started'}),
      isA<VpnStarted>(),
    );
    final stopped = AndroidVpnPlatform.parseEvent({
      'status': 'stopped',
      'error': null,
    });
    expect((stopped! as VpnStopped).error, isNull);
    final failed = AndroidVpnPlatform.parseEvent({
      'status': 'stopped',
      'error': 'bind: denied',
    });
    expect((failed! as VpnStopped).error!.message, 'bind: denied');
    expect(AndroidVpnPlatform.parseEvent({'status': 'starting'}), isNull);
    expect(AndroidVpnPlatform.parseEvent('junk'), isNull);
  });

  test('start sends config and maps permission errors', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start' && (call.arguments as Map)['name'] == 'deny') {
        throw PlatformException(code: 'PERMISSION_DENIED');
      }
      if (call.method == 'isRunning') return true;
      return null;
    });
    final platform = AndroidVpnPlatform();
    await platform.start(
      const VpnStartRequest(configJson: '{}', profileName: 'ok'),
    );
    expect(calls.single.arguments, {'config': '{}', 'name': 'ok'});
    expect(await platform.isRunning(), isTrue);

    await expectLater(
      platform.start(
        const VpnStartRequest(configJson: '{}', profileName: 'deny'),
      ),
      throwsA(
        isA<VpnError>().having(
          (e) => e.code,
          'code',
          VpnErrorCode.permissionDenied,
        ),
      ),
    );
  });
}

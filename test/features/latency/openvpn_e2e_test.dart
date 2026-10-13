@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/windows_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/data/speed_tester.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/openvpn_fixtures.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// Imports OpenVPN profiles and downloads through them from a local
/// OpenVPN server (sing-box's own `openvpn-server`):
///
///     SING_BOX_BIN=build/core/sing-box flutter test --tags singbox
///
/// (build/core/sing-box comes from `scripts/build_core.sh linux amd64
/// build/core/sing-box`; it needs the `with_openvpn` tag.)
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN (with OpenVPN) to run'
      : null;

  test('OpenVPN profiles carry traffic', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('openvpn-e2e');
    addTearDown(() => dir.delete(recursive: true));

    // Reached at the server's tunnel address, 10.8.x.1.
    final http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    addTearDown(() => http.close(force: true));
    final chunk = Uint8List(64 * 1024);
    http.listen((request) async {
      try {
        if (request.uri.path == '/blob') {
          for (var i = 0; i < 200; i++) {
            request.response.add(chunk);
            await request.response.flush();
          }
        } else {
          request.response.statusCode = HttpStatus.noContent;
        }
        await request.response.close();
      } on Object {
        // Client stopped reading.
      }
    });

    final udp = await _freePort();
    final tcp = await _freePort();
    Map<String, Object?> server(
      int port,
      String network,
      String subnet,
      Map<String, Object?> tls, {
      String? auth,
    }) => {
      'type': 'openvpn-server',
      'tag': 'ovpn-$network',
      'listen': '127.0.0.1',
      'listen_port': port,
      'network': network,
      'address': [subnet],
      'users': [
        {'username': 'alice', 'password': 's3cret'},
      ],
      'auth': ?auth,
      'tls': {'certificate': ovpnServerCert, 'key': ovpnServerKey, ...tls},
    };
    final serverConfig = File('${dir.path}/server.json')
      ..writeAsStringSync(
        jsonEncode({
          'log': {'level': 'error'},
          'endpoints': [
            // Client certificate + tls-auth (signed with `auth`) over UDP.
            server(udp, 'udp', '10.8.0.1/24', {
              'client_certificate': ovpnCa,
              'control_wrap': {
                'type': 'tls_auth',
                'key': ovpnStaticKey,
                'direction': 'server',
              },
            }, auth: 'SHA256'),
            // Login only + tls-crypt over TCP.
            server(tcp, 'tcp', '10.8.1.1/24', {
              'verify_client_certificate': 'none',
              'control_wrap': {'type': 'tls_crypt', 'key': ovpnStaticKey},
            }),
          ],
          'outbounds': [
            {'type': 'direct'},
          ],
        }),
      );
    final core = await Process.start(binary!, ['run', '-c', serverConfig.path]);
    addTearDown(core.kill);
    await Future<void>.delayed(const Duration(seconds: 1));

    final udpProfile = SubscriptionParser.parse('''
client
dev tun
proto udp
remote 127.0.0.1 $udp
remote-cert-tls server
auth SHA256
auth-user-pass
key-direction 1
<ca>
$ovpnCa</ca>
<cert>
$ovpnClientCert</cert>
<key>
$ovpnClientKey</key>
<tls-auth>
$ovpnStaticKey</tls-auth>
''', name: 'udp').proxies.single;
    expect(udpProfile.needsLogin, isTrue);
    final tcpProfile = SubscriptionParser.parse('''
client
dev tun
proto tcp-client
remote 127.0.0.1 $tcp
<auth-user-pass>
alice
s3cret
</auth-user-pass>
<ca>
$ovpnCa</ca>
<tls-crypt>
$ovpnStaticKey</tls-crypt>
''').proxies.single;
    final wrongPassword = tcpProfile.withLogin('alice', 'nope');

    final platform = WindowsVpnPlatform(
      coreExecutable: binary,
      dataDirectory: () async => dir,
      elevationCheck: () async => true,
    );
    const options = CoreOptions(directDns: '1.1.1.1');

    // Latency right after the core starts: the test waits for sign-in.
    final latency = LatencyTester(
      platform: platform,
      options: options,
      url: 'http://10.8.0.1:${http.port}/ping',
      timeout: const Duration(seconds: 3),
    );
    final delays = {
      for (final u in await latency.run({
        'udp': udpProfile.withLogin('alice', 's3cret'),
        'no-login': udpProfile,
        'wrong': wrongPassword,
      }).toList())
        u.id: u.result,
    };
    expect(delays['udp']!.delay, isNotNull, reason: 'UDP should answer');
    expect(delays['no-login']!.ok, isFalse);
    expect(delays['wrong']!.ok, isFalse);

    final tester = SpeedTester(
      platform: platform,
      options: options,
      url: 'http://10.8.1.1:${http.port}/blob',
      duration: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 5),
    );
    final speeds = {
      for (final u in await tester.run({'tcp': tcpProfile}).toList())
        u.id: u.result,
    };
    expect(
      speeds['tcp']!.bytesPerSecond,
      greaterThan(SpeedTester.minBytes),
      reason: 'TCP + tls-crypt should download',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('OpenVPN through an HTTP or SOCKS proxy', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('openvpn-proxy-e2e');
    addTearDown(() => dir.delete(recursive: true));

    final http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    addTearDown(() => http.close(force: true));
    final chunk = Uint8List(64 * 1024);
    http.listen((request) async {
      try {
        for (var i = 0; i < 100; i++) {
          request.response.add(chunk);
          await request.response.flush();
        }
        await request.response.close();
      } on Object {
        // Client stopped reading.
      }
    });

    final tcp = await _freePort();
    final udp = await _freePort();
    final httpProxy = await _freePort();
    final socksProxy = await _freePort();
    Map<String, Object?> server(int port, String network, String subnet) => {
      'type': 'openvpn-server',
      'tag': 'ovpn-$network',
      'listen': '127.0.0.1',
      'listen_port': port,
      'network': network,
      'address': [subnet],
      'users': [
        {'username': 'alice', 'password': 's3cret'},
      ],
      'tls': {
        'certificate': ovpnServerCert,
        'key': ovpnServerKey,
        'verify_client_certificate': 'none',
        'control_wrap': {'type': 'tls_crypt', 'key': ovpnStaticKey},
      },
    };
    final log = File('${dir.path}/server.log');
    final serverConfig = File('${dir.path}/server.json')
      ..writeAsStringSync(
        jsonEncode({
          'log': {'level': 'info', 'output': log.path},
          'inbounds': [
            {
              'type': 'http',
              'tag': 'http-proxy-in',
              'listen': '127.0.0.1',
              'listen_port': httpProxy,
              'users': [
                {'username': 'bob', 'password': 'pw'},
              ],
            },
            {
              'type': 'socks',
              'tag': 'socks-proxy-in',
              'listen': '127.0.0.1',
              'listen_port': socksProxy,
            },
          ],
          'endpoints': [
            server(tcp, 'tcp', '10.8.2.1/24'),
            server(udp, 'udp', '10.8.3.1/24'),
          ],
          'outbounds': [
            {'type': 'direct'},
          ],
        }),
      );
    final core = await Process.start(binary!, ['run', '-c', serverConfig.path]);
    addTearDown(core.kill);
    await Future<void>.delayed(const Duration(seconds: 1));

    String profile(String proto, int port, String proxy) =>
        '''
client
dev tun
proto $proto
remote 127.0.0.1 $port
$proxy
<auth-user-pass>
alice
s3cret
</auth-user-pass>
<ca>
$ovpnCa</ca>
<tls-crypt>
$ovpnStaticKey</tls-crypt>
''';
    final viaHttp = SubscriptionParser.parse(
      profile(
        'tcp-client',
        tcp,
        'http-proxy 127.0.0.1 $httpProxy\n'
            '<http-proxy-user-pass>\nbob\npw\n</http-proxy-user-pass>',
      ),
    ).proxies.single;
    final viaSocks = SubscriptionParser.parse(
      profile('udp', udp, 'socks-proxy 127.0.0.1 $socksProxy'),
    ).proxies.single;
    expect(viaHttp.via!.protocol.singBoxType, 'http');
    expect(viaSocks.via!.protocol.singBoxType, 'socks');

    final platform = WindowsVpnPlatform(
      coreExecutable: binary,
      dataDirectory: () async => dir,
      elevationCheck: () async => true,
    );
    Future<double?> speed(String subnetHost, ProxyConfig config) async {
      final tester = SpeedTester(
        platform: platform,
        options: const CoreOptions(directDns: '1.1.1.1'),
        url: 'http://$subnetHost:${http.port}/blob',
        duration: const Duration(seconds: 1),
        connectTimeout: const Duration(seconds: 5),
      );
      final updates = await tester.run({'x': config}).toList();
      return updates.single.result.bytesPerSecond?.toDouble();
    }

    expect(
      await speed('10.8.2.1', viaHttp),
      greaterThan(SpeedTester.minBytes),
      reason: 'OpenVPN over TCP through the HTTP proxy should download',
    );
    expect(
      await speed('10.8.3.1', viaSocks),
      greaterThan(SpeedTester.minBytes),
      reason: 'OpenVPN over UDP through the SOCKS proxy should download',
    );

    // The traffic really went through the proxies.
    final text = await log.readAsString();
    expect(text, contains('inbound/http[http-proxy-in]'));
    expect(text, contains('inbound/socks[socks-proxy-in]'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

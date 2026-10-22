import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/protocols/openconnect.dart';
import 'package:aghelan_ghiamat/core/singbox/protocols/openvpn.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'openvpn_fixtures.dart';

void main() {
  group('OpenVPN profiles', () {
    test('a seller profile becomes an openvpn-client endpoint', () {
      expect(isOpenVpnProfile(ovpnProfile), isTrue);
      final config = parseOpenVpn(ovpnProfile, name: 'de.ovpn');
      final out = config.outbound;
      expect(config.protocol, ProxyProtocol.openvpn);
      expect(config.protocol.isEndpoint, isTrue);
      expect(config.name, 'Germany 1');
      expect(config.server, 'vpn.example.com');
      expect(config.port, 1194);
      expect(out['type'], 'openvpn-client');
      expect(out['servers'], [
        {'server': 'vpn.example.com', 'server_port': 1194, 'network': 'udp'},
        {'server': '2.3.4.5', 'server_port': 443, 'network': 'tcp'},
      ]);
      expect(out['network'], 'udp');

      final tls = out['tls']! as Map;
      expect(tls['certificate'], ovpnCa.trim());
      // The OpenSSL dump in front of the certificate is dropped.
      expect(tls['client_certificate'], ovpnClientCert.trim());
      expect(tls['client_key'], ovpnClientKey.trim());
      expect(tls['remote_certificate_tls'], 'server');
      expect(tls['control_wrap'], {
        'type': 'tls_auth',
        'key': ovpnStaticKey.trim(),
        'direction': 'client',
      });

      // `cipher` alone: offered with the modern ones and used as fallback.
      expect(out['data_ciphers'], [
        'AES-256-GCM',
        'AES-128-GCM',
        'CHACHA20-POLY1305',
        'AES-256-CBC',
      ]);
      expect(out['data_ciphers_fallback'], 'AES-256-CBC');
      expect(out['auth'], 'SHA256');
      expect(out['compression_lzo'], 'adaptive');
      expect(out['allow_compression'], 'asym');

      // auth-user-pass without the login: the user types it in.
      expect(config.needsLogin, isTrue);
      final signedIn = config.withLogin('bob', 'pw');
      expect(signedIn.needsLogin, isFalse);
      expect(signedIn.outbound['username'], 'bob');
      expect(signedIn.outbound['password'], 'pw');
    });

    test('tls-crypt over TCP with the login inside', () {
      final config = parseOpenVpn(ovpnTlsCrypt, name: 'nl');
      final out = config.outbound;
      expect(config.name, 'nl');
      expect(out['server'], '5.6.7.8');
      expect(out['server_port'], 443);
      expect(out['network'], 'tcp');
      expect(out['username'], 'alice');
      expect(out['password'], 's3cret');
      expect(config.needsLogin, isFalse);
      expect(out['data_ciphers'], ['AES-128-GCM', 'CHACHA20-POLY1305']);
      expect(out.containsKey('data_ciphers_fallback'), isFalse);
      expect(out['renegotiate_disabled'], isTrue);
      expect(out['ping_interval'], '10s');
      expect(out['ping_restart'], '60s');
      final tls = out['tls']! as Map;
      expect(tls['server_name'], 'server');
      expect(tls['server_name_type'], 'name');
      expect((tls['control_wrap']! as Map)['type'], 'tls_crypt');
      expect(tls.containsKey('client_certificate'), isFalse);
      expect(config.summary, 'tcp · tls-crypt');
    });

    test('pasted or downloaded profiles go through the normal import', () {
      final result = SubscriptionParser.parse(ovpnProfile, name: 'x');
      expect(result.proxies.single.protocol, ProxyProtocol.openvpn);
      expect(result.skipped, isEmpty);
    });

    test('profiles this client cannot use are skipped with a reason', () {
      String without(String block) => ovpnTlsCrypt.replaceFirst(
        RegExp('<$block>[\\s\\S]*</$block>\\n'),
        '',
      );
      final cases = {
        'separate CA file': '${without('ca')}ca ca.crt\n',
        'no CA': without('ca'),
        'TAP': ovpnTlsCrypt.replaceFirst('dev tun', 'dev tap'),
        'proxy password in a file':
            '${ovpnTlsCrypt}http-proxy 1.2.3.4 8080 creds.txt basic\n',
        'HTTP proxy over UDP':
            '${ovpnTlsCrypt.replaceFirst('proto tcp-client', 'proto udp')}'
            'http-proxy 1.2.3.4 8080\n',
        'OTP': '${ovpnTlsCrypt}static-challenge "OTP" 1\n',
        'separate tls-auth file': '${without('tls-crypt')}tls-auth ta.key 1\n',
      };
      for (final MapEntry(key: reason, value: text) in cases.entries) {
        final result = SubscriptionParser.parse(text);
        expect(result.proxies, isEmpty, reason: reason);
        expect(result.skipped, hasLength(1), reason: reason);
      }
    });

    test('http-proxy and socks-proxy become the first hop', () {
      final viaHttp = parseOpenVpn(
        '${ovpnTlsCrypt}http-proxy proxy.example.com 3128 auto\n'
        'http-proxy-option CUSTOM-HEADER Host cdn.example.com\n'
        'http-proxy-option AGENT Mozilla/5.0\n'
        '<http-proxy-user-pass>\nbob\npw\n</http-proxy-user-pass>\n',
      );
      expect(viaHttp.via!.protocol, ProxyProtocol.http);
      expect(viaHttp.via!.outbound, {
        'type': 'http',
        'server': 'proxy.example.com',
        'server_port': 3128,
        'username': 'bob',
        'password': 'pw',
        'headers': {'Host': 'cdn.example.com', 'User-Agent': 'Mozilla/5.0'},
      });
      expect(viaHttp.via!.isConsistent, isTrue);
      expect(viaHttp.isInsecure, isFalse);

      final viaSocks = parseOpenVpn(
        '${ovpnTlsCrypt.replaceFirst('proto tcp-client', 'proto udp')}'
        'socks-proxy 10.0.0.1\n',
      );
      expect(viaSocks.via!.outbound, {
        'type': 'socks',
        'server': '10.0.0.1',
        'server_port': 1080,
        'version': '5',
      });

      // The chain survives storage and reaches the core config.
      final stored = ProxyConfig.fromJson(viaHttp.toJson());
      expect(stored.via!.outbound['type'], 'http');
    });

    test('quoting, comments and peer fingerprints', () {
      final config = parseOpenVpn('''
client
dev tun
remote "my server.example.com" 1195 # comment
;remote ignored.example.com
peer-fingerprint $ovpnServerFingerprint
''');
      expect(config.server, 'my server.example.com');
      expect(config.port, 1195);
      final tls = config.outbound['tls']! as Map;
      expect(tls['peer_fingerprint'], [
        ovpnServerFingerprint.replaceAll(':', '').toLowerCase(),
      ]);
      expect(config.needsLogin, isFalse);
    });

    test('static-key profiles', () {
      final config = parseOpenVpn('''
dev tun
remote 1.2.3.4 1194
ifconfig 10.9.0.2 10.9.0.1
secret [inline] 1
cipher aes-256-cbc
<secret>
$ovpnStaticKey</secret>
''');
      final out = config.outbound;
      expect(out['mode'], 'static_key');
      expect(out['static_key'], ovpnStaticKey.trim());
      expect(out['key_direction'], 'client');
      expect(out['address'], ['10.9.0.2/32']);
      expect(out['peer_address'], '10.9.0.1');
      expect(out['cipher'], 'AES-256-CBC');
      expect(out.containsKey('tls'), isFalse);
    });

    test('a bare key-direction does not break a static-key profile', () {
      final config = parseOpenVpn('''
dev tun
remote 1.2.3.4 1194
ifconfig 10.9.0.2 10.9.0.1
secret [inline]
key-direction
cipher aes-256-cbc
<secret>
$ovpnStaticKey</secret>
''');
      expect(config.outbound['mode'], 'static_key');
      expect(config.outbound.containsKey('key_direction'), isFalse);
    });

    test('share links are not mistaken for profiles', () {
      expect(isOpenVpnProfile('vless://x@remote.example.com:443#a'), isFalse);
    });
  });

  group('Cisco AnyConnect', () {
    test('form input becomes an openconnect endpoint with a link', () {
      final config = openConnectConfig(
        address: 'vpn.example.com:4443',
        username: 'bob',
        password: 'p@ss:w',
        group: 'Fast',
        name: 'Cisco DE',
      );
      expect(config.protocol, ProxyProtocol.openconnect);
      expect(config.server, 'vpn.example.com');
      expect(config.port, 4443);
      expect(config.outbound, {
        'type': 'openconnect',
        'server': 'https://vpn.example.com:4443',
        'username': 'bob',
        'password': 'p@ss:w',
        'auth_group': 'Fast',
      });
      expect(config.needsLogin, isFalse);

      final again = LinkParser.parse(config.link!);
      expect(again.outbound, config.outbound);
      expect(again.name, 'Cisco DE');
    });

    test('links with a pinned certificate and default port', () {
      final config = LinkParser.parse(
        'anyconnect://u:p@1.2.3.4/office?pin=pin-sha256%3AabcdEF%3D#Work',
      );
      expect(config.port, 443);
      expect(config.outbound['server'], 'https://1.2.3.4:443/office');
      expect(config.outbound['tls'], {
        'peer_fingerprint': ['pin-sha256:abcdEF='],
      });
      expect(config.name, 'Work');
    });

    test('a changed login updates the link', () {
      final config = openConnectConfig(
        address: 'vpn.example.com',
        username: '',
        password: '',
      );
      expect(config.needsLogin, isTrue);
      final signedIn = config.withLogin('carol', 'x');
      expect(LinkParser.parse(signedIn.link!).outbound['username'], 'carol');
    });

    test('sing-box JSON with openconnect and openvpn endpoints', () {
      final result = SubscriptionParser.parse('''
{"endpoints": [
  {"type": "openconnect", "tag": "oc", "server": "vpn.example.com:8443",
   "username": "a", "password": "b"},
  {"type": "openvpn-client", "tag": "ov",
   "servers": [{"server": "1.2.3.4", "server_port": 1194}],
   "tls": {"certificate": "x"}}
]}''');
      expect(result.proxies.map((p) => '${p.server}:${p.port}'), [
        'vpn.example.com:8443',
        '1.2.3.4:1194',
      ]);
    });
  });
}

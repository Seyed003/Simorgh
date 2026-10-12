import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/dns_server.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

List<Map<String, Object?>> _list(Object? v) =>
    (v! as List).map((e) => (e as Map).cast<String, Object?>()).toList();

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();

void main() {
  const api = ClashApiOptions(port: 19090, secret: 's3cr3t');

  group('SingBoxConfigBuilder', () {
    test('android TUN config around a VLESS outbound', () {
      final proxy = LinkParser.parse(vlessWs);
      final config = const SingBoxConfigBuilder(
        options: CoreOptions(),
        platform: CorePlatform.android,
        clashApi: api,
      ).build(proxy);

      final inbounds = _list(config['inbounds']);
      expect(inbounds.single['type'], 'tun');
      expect(inbounds.single['address'], ['172.19.0.1/30']);
      expect(inbounds.single.containsKey('interface_name'), isFalse);

      final outbounds = _list(config['outbounds']);
      expect(outbounds.map((o) => o['tag']), ['proxy', 'direct']);
      // Default fingerprint is applied when the link has none.
      expect(_map(outbounds.first['tls'])['utls'], {
        'enabled': true,
        'fingerprint': 'chrome',
      });
      // ...without mutating the stored profile.
      expect(_map(proxy.outbound['tls']).containsKey('utls'), isFalse);

      final route = _map(config['route']);
      expect(route['final'], 'proxy');
      expect(_list(route['rules']).first, {'action': 'sniff'});

      final dns = _map(config['dns']);
      final servers = _list(dns['servers']);
      expect(servers.first, {
        'type': 'https',
        'tag': 'dns-remote',
        'server': '1.1.1.1',
        'detour': 'proxy',
      });
      expect(servers[1], {
        'type': 'udp',
        'tag': 'dns-direct',
        'server': '1.1.1.1',
      });
      expect(dns['strategy'], 'ipv4_only');

      expect(_map(config['experimental'])['clash_api'], {
        'external_controller': '127.0.0.1:19090',
        'secret': 's3cr3t',
      });
    });

    test(
      'windows config names the interface, adds IPv6 and the mixed port',
      () {
        final config = const SingBoxConfigBuilder(
          options: CoreOptions(enableIpv6: true, mixedPort: 2080),
          platform: CorePlatform.windows,
        ).build(LinkParser.parse(trojanTls));
        final inbounds = _list(config['inbounds']);
        expect(inbounds.first['interface_name'], 'AghelanGhiamat');
        expect(inbounds.first['address'], [
          '172.19.0.1/30',
          'fdfe:dcba:9876::1/126',
        ]);
        expect(inbounds.last, {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': 2080,
        });
        expect(_map(config['dns'])['strategy'], 'prefer_ipv4');
      },
    );

    test('WireGuard goes to endpoints', () {
      final config = const SingBoxConfigBuilder(
        options: CoreOptions(),
        platform: CorePlatform.android,
      ).build(LinkParser.parse(wireguard));
      expect(_list(config['endpoints']).single['tag'], 'proxy');
      expect(_list(config['outbounds']).map((o) => o['tag']), ['direct']);
    });

    test('fingerprint is not forced on QUIC protocols or when disabled', () {
      final hy = const SingBoxConfigBuilder(
        options: CoreOptions(),
        platform: CorePlatform.android,
      ).build(LinkParser.parse(hy2));
      expect(
        _map(_list(hy['outbounds']).first['tls']).containsKey('utls'),
        isFalse,
      );

      final noFp = SingBoxConfigBuilder(
        options: const CoreOptions().copyWith(defaultFingerprint: () => null),
        platform: CorePlatform.android,
      ).build(LinkParser.parse(trojanBare));
      expect(
        _map(_list(noFp['outbounds']).first['tls']).containsKey('utls'),
        isFalse,
      );
    });

    test('domain based DNS servers get resolvers', () {
      final config = const SingBoxConfigBuilder(
        options: CoreOptions(
          remoteDns: 'https://dns.google/dns-query',
          directDns: 'tls://dns.quad9.net',
        ),
        platform: CorePlatform.windows,
      ).build(LinkParser.parse(trojanBare));
      final servers = _list(_map(config['dns'])['servers']);
      expect(servers[0]['domain_resolver'], 'dns-direct');
      expect(servers[1]['domain_resolver'], 'dns-local');
      expect(servers[2], {'type': 'local', 'tag': 'dns-local'});
    });
  });

  group('parseDnsServer', () {
    test('formats', () {
      expect(parseDnsServer('local', tag: 't'), {'type': 'local', 'tag': 't'});
      expect(parseDnsServer('8.8.8.8', tag: 't'), {
        'type': 'udp',
        'tag': 't',
        'server': '8.8.8.8',
      });
      expect(parseDnsServer('udp://8.8.4.4:5353', tag: 't'), {
        'type': 'udp',
        'tag': 't',
        'server': '8.8.4.4',
        'server_port': 5353,
      });
      expect(parseDnsServer('tls://1.1.1.1', tag: 't')['type'], 'tls');
      expect(
        parseDnsServer('quic://dns.adguard.com', tag: 't')['type'],
        'quic',
      );
      expect(parseDnsServer('https://dns.example.com/custom', tag: 't'), {
        'type': 'https',
        'tag': 't',
        'server': 'dns.example.com',
        'path': '/custom',
      });
      expect(parseDnsServer('h3://1.1.1.1/dns-query', tag: 't')['type'], 'h3');
      expect(
        () => parseDnsServer('ftp://x', tag: 't'),
        throwsA(isA<LinkParseException>()),
      );
    });
  });

  test('CoreOptions JSON round trip and equality', () {
    const options = CoreOptions(
      mixedPort: 1080,
      enableIpv6: true,
      logLevel: 'info',
    );
    final restored = CoreOptions.fromJson(options.toJson());
    expect(restored, options);
    expect(restored.copyWith(mixedPort: () => null).mixedPort, isNull);
  });
}

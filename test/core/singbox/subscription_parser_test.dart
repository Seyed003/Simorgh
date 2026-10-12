import 'dart:convert';

import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_info.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('SubscriptionParser', () {
    final plain = [
      '# comment line',
      vlessReality,
      '',
      trojanTls,
      'vless://broken',
      vlessXhttp,
      hy2,
    ].join('\r\n');

    test('plain text list with comments and broken lines', () {
      final result = SubscriptionParser.parse(plain);
      expect(result.proxies.map((p) => p.protocol), [
        ProxyProtocol.vless,
        ProxyProtocol.trojan,
        ProxyProtocol.vless,
        ProxyProtocol.hysteria2,
      ]);
      expect(result.proxies[2].outbound['type'], 'xray');
      expect(result.skipped, hasLength(1));
    });

    test('standard base64 with line wrapping', () {
      final encoded = base64.encode(utf8.encode(plain));
      final wrapped = RegExp('.{1,76}')
          .allMatches(encoded)
          .map((m) => m.group(0))
          .join('\n');
      final result = SubscriptionParser.parse(wrapped);
      expect(result.proxies, hasLength(4));
    });

    test('URL-safe base64 without padding', () {
      final encoded = base64Url
          .encode(utf8.encode('$ssSip002\n$tuic\n'))
          .replaceAll('=', '');
      final result = SubscriptionParser.parse(encoded);
      expect(result.proxies.map((p) => p.protocol), [
        ProxyProtocol.shadowsocks,
        ProxyProtocol.tuic,
      ]);
    });

    test('several links on one line, remark with spaces preserved', () {
      final result = SubscriptionParser.parse(
        '$vlessWs $trojanBare\t$ssSip002',
      );
      expect(result.proxies.map((p) => p.name), [
        'My Server 1',
        'bare',
        'SS 1',
      ]);
    });

    test('nested base64 block inside a plain list', () {
      final nested = base64.encode(utf8.encode('$anytls\n$socks'));
      final result = SubscriptionParser.parse('$hy2\n$nested');
      expect(result.proxies, hasLength(3));
    });

    test('sing-box config JSON imports proxy outbounds and endpoints', () {
      final config = jsonEncode({
        'outbounds': [
          {
            'type': 'selector',
            'tag': 'select',
            'outbounds': ['a'],
          },
          {
            'type': 'vless',
            'tag': 'my-vless',
            'server': 'v.example.com',
            'server_port': 443,
            'uuid': uuid,
            'detour': 'other',
            'domain_resolver': 'local',
          },
          {'type': 'direct', 'tag': 'direct'},
        ],
        'endpoints': [
          {
            'type': 'wireguard',
            'tag': 'wg',
            'address': ['10.0.0.2/32'],
            'private_key': wgPrivate,
            'peers': [
              {'address': '9.9.9.9', 'port': 51820, 'public_key': wgPublic},
            ],
          },
        ],
      });
      final result = SubscriptionParser.parse(config);
      expect(result.proxies, hasLength(2));
      final vless = result.proxies.first;
      expect(vless.name, 'my-vless');
      expect(vless.outbound.containsKey('tag'), isFalse);
      expect(vless.outbound.containsKey('detour'), isFalse);
      expect(vless.outbound.containsKey('domain_resolver'), isFalse);
      expect(result.proxies.last.protocol, ProxyProtocol.wireguard);
      expect(result.proxies.last.server, '9.9.9.9');
      expect(result.proxies.last.port, 51820);
    });

    test('Xray JSON configs run on the Xray engine', () {
      final json = jsonEncode([
        {
          'remarks': 'DE xhttp',
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'de.example.com',
                    'port': 443,
                    'users': [
                      {'id': uuid, 'encryption': 'none'},
                    ],
                  },
                ],
              },
              'streamSettings': {
                'network': 'xhttp',
                'security': 'tls',
                'tlsSettings': {
                  'serverName': 'de.example.com',
                  'allowInsecure': true,
                },
                'sockopt': {'dialerProxy': 'frag'},
              },
            },
            {
              'tag': 'frag',
              'protocol': 'freedom',
              'settings': {
                'fragment': {'packets': 'tlshello', 'length': '10-20'},
              },
            },
            {'tag': 'direct', 'protocol': 'freedom'},
          ],
        },
      ]);
      final result = SubscriptionParser.parse(json);
      final proxy = result.proxies.single;
      expect(proxy.name, 'DE xhttp');
      expect(proxy.protocol, ProxyProtocol.vless);
      expect(proxy.server, 'de.example.com');
      expect(proxy.port, 443);
      expect(proxy.outbound['type'], 'xray');
      expect(proxy.outbound['fragment'], {
        'packets': 'tlshello',
        'length': '10-20',
      });
      final xray = proxy.outbound['xray']! as Map;
      expect(xray.containsKey('tag'), isFalse);
      final stream = xray['streamSettings'] as Map;
      expect(stream['sockopt'], isEmpty);
      expect(
        (stream['tlsSettings'] as Map).containsKey('allowInsecure'),
        isFalse,
      );
    });

    test('single outbound object', () {
      final result = SubscriptionParser.parse(
        jsonEncode({
          'type': 'trojan',
          'server': 't.example.com',
          'server_port': 443,
          'password': 'x',
        }),
      );
      expect(result.proxies.single.protocol, ProxyProtocol.trojan);
    });

    test('garbage yields nothing', () {
      expect(SubscriptionParser.parse('hello world').isEmpty, isTrue);
      expect(SubscriptionParser.parse('').isEmpty, isTrue);
      expect(SubscriptionParser.parse('{not json').isEmpty, isTrue);
    });

    test('UTF-8 BOM is ignored', () {
      expect(SubscriptionParser.parse('﻿$vlessReality').proxies, hasLength(1));
    });
  });

  group('SubscriptionInfo', () {
    test('parses usage, expiry, title and interval headers', () {
      final info = SubscriptionInfo.fromHeaders({
        'subscription-userinfo': 'upload=1073741824; download=2147483648; total=10737418240; expire=1798761600',
        'profile-title': 'base64:${base64.encode(utf8.encode('عاقلان'))}',
        'profile-update-interval': '12',
      });
      expect(info.upload, 1073741824);
      expect(info.used, 3221225472);
      expect(info.total, 10737418240);
      expect(info.expire, DateTime.utc(2027, 1, 1));
      expect(info.title, 'عاقلان');
      expect(info.updateInterval, const Duration(hours: 12));
      expect(SubscriptionInfo.fromJson(info.toJson()).toJson(), info.toJson());
    });

    test('falls back to content-disposition file name', () {
      final info = SubscriptionInfo.fromHeaders({
        'content-disposition': 'attachment; filename="My Sub"',
      });
      expect(info.title, 'My Sub');
      expect(info.hasUsage, isFalse);
    });
  });
}

import 'dart:convert';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/subscription_url.dart';
import 'package:aghelan_ghiamat/features/profiles/data/subscription_client.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers.dart';
import 'fixtures.dart';

Map<String, Object?> _built(String text) {
  final proxy = SubscriptionParser.parse(text).proxies.single;
  final config = const SingBoxConfigBuilder(
    options: CoreOptions(),
    platform: CorePlatform.other,
  ).build(proxy);
  return (config['outbounds']! as List).first as Map<String, Object?>;
}

void main() {
  group('configs cannot reach files on the device', () {
    test('Xray key logs and certificate files are dropped', () {
      final outbound = _built(
        jsonEncode({
          'outbounds': [
            {
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'example.com',
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
                  'serverName': 'example.com',
                  'masterKeyLog': r'C:\Windows\System32\evil.dll',
                  'certificates': [
                    {'certificateFile': '/etc/passwd', 'keyFile': '/x'},
                    {
                      'certificate': ['-----BEGIN CERTIFICATE-----'],
                    },
                  ],
                },
                'xhttpSettings': {
                  'path': '/x',
                  'extra': {
                    'downloadSettings': {
                      'security': 'reality',
                      'realitySettings': {'masterKeyLog': '/tmp/keys'},
                    },
                  },
                },
              },
            },
          ],
        }),
      );
      final text = jsonEncode(outbound);
      expect(text, isNot(contains('masterKeyLog')));
      expect(text, isNot(contains('certificateFile')));
      expect(text, isNot(contains('/etc/passwd')));
      // Inline certificates and everything else stay.
      expect(text, contains('BEGIN CERTIFICATE'));
      expect(text, contains('downloadSettings'));
      expect(text, contains('example.com'));
    });

    test('Xray links with such fields in xhttp "extra" lose them too', () {
      final extra = Uri.encodeComponent(
        jsonEncode({
          'downloadSettings': {
            'tlsSettings': {'masterKeyLog': '/sdcard/keys.log'},
          },
        }),
      );
      final outbound = _built(
        'vless://$uuid@example.com:443?security=tls&type=xhttp&path=%2Fx'
        '&extra=$extra#x',
      );
      expect(jsonEncode(outbound), isNot(contains('masterKeyLog')));
    });

    test('sing-box *_path options are dropped from imported JSON', () {
      final outbound = _built(
        jsonEncode({
          'type': 'trojan',
          'tag': 't',
          'server': 'example.com',
          'server_port': 443,
          'password': 'p',
          'tls': {
            'enabled': true,
            'server_name': 'example.com',
            'certificate_path': r'C:\Users\me\secret.pem',
            'client_key_path': '/data/data/x/key',
          },
        }),
      );
      final tls = outbound['tls']! as Map;
      expect(tls.keys, isNot(contains('certificate_path')));
      expect(tls.keys, isNot(contains('client_key_path')));
      expect(tls['server_name'], 'example.com');
    });
  });

  group('insecure configs are marked', () {
    test('SSH without the server key, and chains through one', () {
      final open = LinkParser.parse('ssh://root:pw@1.2.3.4:22#open');
      final pinned = LinkParser.parse(
        'ssh://root:pw@1.2.3.4:22?hk=ssh-ed25519%20AAAAC3Nza#pinned',
      );
      expect(open.isInsecure, isTrue);
      expect(pinned.isInsecure, isFalse);
      final tls = LinkParser.parse(trojanBare);
      expect(tls.isInsecure, isFalse);
      expect(tls.chainedVia(open).isInsecure, isTrue);
      expect(tls.chainedVia(pinned).isInsecure, isFalse);
    });
  });

  group('malformed input is skipped, not fatal', () {
    test('a bad line leaves the rest of a subscription', () {
      final result = SubscriptionParser.parse(
        'vless://$uuid@example.com:443?security=tls&type=ws&host=,#bad\n'
        '$vlessWs',
      );
      expect(result.proxies, hasLength(1));
      expect(result.skipped, hasLength(1));
    });

    test('Xray JSON with fields of the wrong type', () {
      final result = SubscriptionParser.parse(
        jsonEncode({
          'outbounds': [
            {
              'protocol': 'vless',
              'settings': {'vnext': 'nope'},
              'streamSettings': {'tlsSettings': 7},
            },
          ],
        }),
      );
      expect(result.proxies, isEmpty);
    });

    test('nested OpenVPN <connection> blocks parse quickly', () {
      final nested = List.filled(20000, '<connection>').join('\n');
      final watch = Stopwatch()..start();
      final result = SubscriptionParser.parse(
        'client\ndev tun\nremote 1.2.3.4 1194\n$nested\n',
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(result.proxies.length + result.skipped.length, 1);
    });
  });

  group('local proxy password', () {
    test('a proxy port without a password gets one', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({
              'settings.core': jsonEncode({'mixedPort': 2080}),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      final options = container.read(coreOptionsProvider);
      expect(options.mixedCredentials, isNotNull);
      expect(options.mixedPassword, hasLength(16));
      // Kept: the same password after a restart.
      final saved = jsonDecode(
        container.read(sharedPreferencesProvider).getString('settings.core')!,
      ) as Map;
      expect(saved['mixedPassword'], options.mixedPassword);
    });

    test('switching auth off is respected', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({
              'settings.core': jsonEncode({
                'mixedPort': 2080,
                'mixedAuth': false,
              }),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(coreOptionsProvider).mixedCredentials, isNull);
    });
  });

  group('subscriptions', () {
    test('a huge response is refused', () async {
      final client = SubscriptionClient(
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable(List.filled(9, List.filled(1024 * 1024, 0x41))),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch('https://example.com/sub'),
        throwsA(isA<SubscriptionException>()),
      );
    });

    test('a normal one still downloads', () async {
      final client = SubscriptionClient(
        MockClient((_) async => http.Response(vlessWs, 200)),
      );
      expect((await client.fetch('https://example.com/sub')).body, vlessWs);
    });

    test('plain http is told apart', () {
      expect(isPlainHttp('http://1.2.3.4:2096/sub/x'), isTrue);
      expect(isPlainHttp('https://example.com/sub'), isFalse);
    });
  });
}

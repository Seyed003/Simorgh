import 'dart:convert';
import 'dart:math';

import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/warp/application/warp_service.dart';
import 'package:aghelan_ghiamat/features/warp/data/warp_client.dart';
import 'package:aghelan_ghiamat/features/warp/data/x25519.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

/// What Cloudflare answers to a registration (trimmed).
String warpAnswer({String clientId = 'AQID'}) => jsonEncode({
  'id': 'device-id',
  'token': 'tok',
  'config': {
    'client_id': clientId,
    'peers': [
      {
        'public_key': warpPeerKey,
        'endpoint': {
          'v4': '162.159.192.7:0',
          'host': 'engage.cloudflareclient.com:2408',
        },
      },
    ],
    'interface': {
      'addresses': {'v4': '172.16.0.2', 'v6': '2606:4700:110:8a36::1'},
    },
  },
});

void main() {
  test('registers with a fresh key and builds a WireGuard config', () async {
    late Map<String, Object?> sent;
    final client = WarpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${WarpClient.defaultApi}/reg');
        sent = (jsonDecode(request.body) as Map).cast<String, Object?>();
        return http.Response(warpAnswer(), 200);
      }),
    );
    final account = await client.register(random: Random(7));
    // The public key sent belongs to the private key kept.
    expect(
      base64.encode(
        x25519(base64.decode(account.privateKey), [9, ...List.filled(31, 0)]),
      ),
      sent['key'],
    );
    expect(account.reserved, [1, 2, 3]);

    final config = account.config();
    expect(config.protocol, ProxyProtocol.wireguard);
    expect(isWarp(config), isTrue);
    expect(config.outbound['address'], [
      '172.16.0.2/32',
      '2606:4700:110:8a36::1/128',
    ]);
    final peer = (config.outbound['peers']! as List).single as Map;
    expect(peer['address'], '162.159.192.1');
    expect(peer['port'], 2408);
    expect(peer['reserved'], [1, 2, 3]);
    expect(peer['public_key'], warpPeerKey);
    expect(config.outbound['private_key'], account.privateKey);
    expect(isWarp(LinkParser.parse(wireguard)), isFalse);
  });

  test('registration failures are reported', () async {
    for (final response in [
      http.Response('nope', 403),
      http.Response('<html>', 200),
      http.Response('{"config":{}}', 200),
    ]) {
      final client = WarpClient(MockClient((_) async => response));
      expect(client.register(), throwsA(isA<WarpException>()));
    }
    final offline = WarpClient(
      MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(offline.register(), throwsA(isA<WarpException>()));
  });

  test('blocked API falls back to a clean Cloudflare IP', () async {
    final tried = <String>[];
    final client = WarpClient(
      // The API's own address is blocked.
      MockClient((_) async => throw http.ClientException('blocked')),
      cleanIps: (host) async {
        expect(host, 'api.cloudflareclient.com');
        return ['1.1.1.2', '1.0.0.3'];
      },
      clientForIp: (ip) => MockClient((request) async {
        tried.add(ip);
        expect(request.url.toString(), '${WarpClient.defaultApi}/reg');
        // The first clean IP is dead; the second answers.
        if (ip == '1.1.1.2') throw http.ClientException('reset');
        return http.Response(warpAnswer(), 200);
      }),
    );
    final account = await client.register(random: Random(1));
    expect(tried, ['1.1.1.2', '1.0.0.3']);
    expect(isWarp(account.config()), isTrue);
  });

  test('without a clean-IP finder a blocked API still just fails', () async {
    final client = WarpClient(
      MockClient((_) async => throw http.ClientException('blocked')),
    );
    expect(client.register(), throwsA(isA<WarpException>()));
  });

  test('endpoint samples and moving a config', () {
    final sample = sampleWarpEndpoints(24, Random(1));
    expect(sample, hasLength(24));
    expect(sample.first, WarpAccount.defaultEndpoint);
    expect(sample.map((e) => '${e.host}:${e.port}').toSet(), hasLength(24));
    for (final e in sample) {
      expect(warpRanges.any((r) => e.host.startsWith('$r.')), isTrue);
      expect(warpPorts, contains(e.port));
    }
    final account = WarpAccount(
      privateKey: base64.encode(List.filled(32, 1)),
      peerPublicKey: warpPeerKey,
      addressV4: '172.16.0.2',
      reserved: const [0, 0, 0],
    );
    final moved = withEndpoint(account.config(), '188.114.97.3', 1701);
    final peer = (moved.outbound['peers']! as List).single as Map;
    expect((peer['address'], peer['port']), ('188.114.97.3', 1701));
    expect((moved.server, moved.port), ('188.114.97.3', 1701));
  });

  test('the fastest answering endpoint wins', () async {
    Future<ProxyConfig?> scan(Map<String, int?> delays) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({}),
          ),
          profileStoreProvider.overrideWithValue(MemoryProfileStore()),
          vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
          warpEndpointProbeProvider.overrideWithValue((variants) async {
            final ids = variants.keys.toList();
            return {
              for (final (i, id) in ids.indexed)
                id: switch (delays['$i']) {
                  final ms? => LatencyResult.success(ms, DateTime(2026)),
                  null => LatencyResult.failure(
                    LatencyFailure.unreachable,
                    DateTime(2026),
                  ),
                },
            };
          }),
        ],
      );
      addTearDown(container.dispose);
      final account = WarpAccount(
        privateKey: base64.encode(List.filled(32, 1)),
        peerPublicKey: warpPeerKey,
        addressV4: '172.16.0.2',
        reserved: const [0, 0, 0],
      );
      return container.read(warpServiceProvider).bestEndpoint(account.config());
    }

    final best = await scan({'3': 400, '7': 120, '9': 300});
    expect(best, isNotNull);
    expect(best!.server, isNot(WarpAccount.defaultEndpoint.host));
    expect(await scan({}), isNull);
  });
}

import 'dart:convert';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';

/// Clash API stub answering /proxies/{tag}/delay from [delays] (tag -> ms,
/// null = 504 timeout).
ClashApiClient Function(ClashApiOptions) stubApi(
  Map<String, int?> delays, {
  List<String>? requested,
}) =>
    (options) => ClashApiClient(
      options,
      clientFactory: () => MockClient((request) async {
        final tag = request.url.pathSegments[1];
        requested?.add(tag);
        expect(request.headers['Authorization'], 'Bearer ${options.secret}');
        expect(request.url.queryParameters['timeout'], '5000');
        final delay = delays[tag];
        return delay == null
            ? http.Response('{"message":"Timeout"}', 504)
            : http.Response(jsonEncode({'delay': delay}), 200);
      }),
    );

void main() {
  test('tests every server and stops the test core', () async {
    final platform = FakeVpnPlatform();
    final requested = <String>[];
    final tester = LatencyTester(
      platform: platform,
      options: const CoreOptions(),
      clientFactory: stubApi({
        't0': 120,
        't1': null,
        't2': 340,
      }, requested: requested),
    );
    final updates = await tester.run({
      'a': LinkParser.parse(vlessReality),
      'b': LinkParser.parse(trojanTls),
      'c': LinkParser.parse(hy2),
    }).toList();

    final byId = {for (final u in updates) u.id: u.result};
    expect(byId['a']!.delay, 120);
    expect(byId['b']!.failure, LatencyFailure.unreachable);
    expect(byId['c']!.delay, 340);
    expect(requested.toSet(), {'t0', 't1', 't2'});
    expect(platform.testerConfigs, hasLength(1));
    expect(platform.stopTesterCalls, 1);
  });

  test('drops servers the core rejects and tests the rest', () async {
    final platform = FakeVpnPlatform()
      ..checkErrors.addAll(['initialize outbound[1]: unsupported flow: bogus']);
    final tester = LatencyTester(
      platform: platform,
      options: const CoreOptions(),
      clientFactory: stubApi({'t0': 80, 't1': 90}),
    );
    final updates = await tester.run({
      'a': LinkParser.parse(vlessReality),
      'bad': LinkParser.parse(trojanTls),
      'c': LinkParser.parse(hy2),
    }).toList();

    final byId = {for (final u in updates) u.id: u.result};
    expect(byId['bad']!.failure, LatencyFailure.invalidConfig);
    expect(byId['a']!.delay, 80);
    // After dropping "bad", "c" moved to tag t1.
    expect(byId['c']!.delay, 90);
    expect(platform.checkedConfigs, hasLength(2));
  });

  test('an error that blames no server fails the whole run', () async {
    final platform = FakeVpnPlatform()..checkErrors.add('listen tcp: in use');
    final tester = LatencyTester(
      platform: platform,
      options: const CoreOptions(),
      clientFactory: stubApi({}),
    );
    final updates = await tester.run({
      'a': LinkParser.parse(vlessReality),
      'b': LinkParser.parse(hy2),
    }).toList();
    expect(updates.map((u) => u.result.failure), [
      LatencyFailure.coreError,
      LatencyFailure.coreError,
    ]);
    expect(platform.testerConfigs, isEmpty);
  });

  test('cancelling stops the test core', () async {
    final platform = FakeVpnPlatform();
    final tester = LatencyTester(
      platform: platform,
      options: const CoreOptions(),
      concurrency: 1,
      clientFactory: stubApi({'t0': 1, 't1': 2, 't2': 3}),
    );
    final first = await tester.run({
      'a': LinkParser.parse(vlessReality),
      'b': LinkParser.parse(trojanTls),
      'c': LinkParser.parse(hy2),
    }).first;
    expect(first.result.delay, 1);
    expect(platform.stopTesterCalls, 1);
  });

  test('result JSON round trip', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1000);
    for (final result in [
      LatencyResult.success(42, at),
      LatencyResult.failure(LatencyFailure.unreachable, at),
    ]) {
      final restored = LatencyResult.fromJson(result.toJson())!;
      expect(restored.delay, result.delay);
      expect(restored.failure, result.failure);
      expect(restored.testedAt, at);
    }
    expect(LatencyResult.fromJson({'x': 1}), isNull);
  });
}

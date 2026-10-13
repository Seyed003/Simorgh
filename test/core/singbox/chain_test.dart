import 'dart:convert';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/test_config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/protocols/openvpn.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'openvpn_fixtures.dart';

void main() {
  final relay = LinkParser.parse(trojanTls);
  final target = LinkParser.parse(vlessReality);

  test('a chained config dials through the first server', () {
    final chained = target.chainedVia(relay);
    final json = const SingBoxConfigBuilder(
      options: CoreOptions(),
      platform: CorePlatform.android,
    ).build(chained);
    final outbounds = (json['outbounds']! as List).cast<Map>();
    final proxy = outbounds.firstWhere((o) => o['tag'] == 'proxy');
    final first = outbounds.firstWhere((o) => o['tag'] == 'proxy-via');
    expect(proxy['type'], 'vless');
    expect(proxy['detour'], 'proxy-via');
    expect(first['type'], 'trojan');
    expect(first.containsKey('detour'), isFalse);
  });

  test('endpoints chain too, and chains stop at three servers', () {
    final ovpn = parseOpenVpn(ovpnTlsCrypt);
    final json = const SingBoxConfigBuilder(
      options: CoreOptions(),
      platform: CorePlatform.android,
    ).build(ovpn.chainedVia(target.chainedVia(relay.chainedVia(target))));
    final endpoints = (json['endpoints']! as List).cast<Map>();
    expect(endpoints.single['tag'], 'proxy');
    expect(endpoints.single['detour'], 'proxy-via');
    final outbounds = (json['outbounds']! as List).cast<Map>();
    expect(outbounds.map((o) => o['tag']), [
      'proxy-via',
      'proxy-via-via',
      'direct',
    ]);
    expect(outbounds.first['detour'], 'proxy-via-via');
    expect(outbounds[1].containsKey('detour'), isFalse);
  });

  test('the chain survives storage, renames and logins', () {
    final chained = target.chainedVia(relay).copyWith(name: 'A ⟵ B');
    final again = ProxyConfig.fromJson(
      (jsonDecode(jsonEncode(chained.toJson())) as Map).cast<String, Object?>(),
    );
    expect(again.name, 'A ⟵ B');
    expect(again.via!.outbound, relay.outbound);
    expect(again.withAddress('1.1.1.1').via, isNotNull);
  });

  test('auto mode and the test core keep each server with its chain', () {
    final chained = target.chainedVia(relay);
    final auto = const SingBoxConfigBuilder(
      options: CoreOptions(),
      platform: CorePlatform.android,
    ).buildAuto([chained, relay]);
    final tags = (auto['outbounds']! as List).map((o) => (o as Map)['tag']);
    expect(tags, containsAll(['auto-0', 'auto-0-via', 'auto-1']));
    expect(((auto['outbounds']! as List).first as Map)['outbounds'], [
      'auto-0',
      'auto-1',
    ]);

    final test = TestConfigBuilder(
      options: const CoreOptions(),
      clashApi: const ClashApiOptions(port: 1, secret: 's'),
    ).build({'a': chained, 'b': relay});
    // Only the servers themselves are measured...
    expect(test.tagToId, {'t0': 'a', 't1': 'b'});
    // ...but an error in a chain's first server blames that config.
    expect(test.idBlamedBy('initialize outbound[1]: bad'), 'a');
    expect(test.idBlamedBy('initialize outbound[2]: bad'), 'b');
  });
}

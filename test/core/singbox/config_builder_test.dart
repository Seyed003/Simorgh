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
        expect(inbounds.first['interface_name'], 'Simorgh');
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

    test('the local proxy asks for a password when one is set', () {
      final config = const SingBoxConfigBuilder(
        options: CoreOptions(mixedPort: 2080, mixedPassword: 'pw'),
        platform: CorePlatform.windows,
      ).build(LinkParser.parse(trojanTls));
      expect(_list(config['inbounds']).last['users'], [
        {'username': 'aghelan', 'password': 'pw'},
      ]);
      final open = const SingBoxConfigBuilder(
        options: CoreOptions(
          mixedPort: 2080,
          mixedPassword: 'pw',
          mixedAuth: false,
        ),
        platform: CorePlatform.windows,
      ).build(LinkParser.parse(trojanTls));
      expect(_list(open['inbounds']).last.containsKey('users'), isFalse);
    });

    test('Xray configs get Xray fragmentation over TLS only', () {
      Map<String, Object?> outbound(String link, TlsFragmentMode mode) => _map(
        _list(
          SingBoxConfigBuilder(
            options: CoreOptions(tlsFragment: mode),
            platform: CorePlatform.android,
          ).build(LinkParser.parse(link))['outbounds'],
        ).first,
      );
      expect(outbound(vlessXhttp, TlsFragmentMode.record)['fragment'], {
        'packets': 'tlshello',
        'length': '100-200',
        'interval': '0',
      });
      expect(
        _map(outbound(vlessXhttp, TlsFragmentMode.tcp)['fragment'])['interval'],
        '10-20',
      );
      expect(outbound(vlessXhttp, TlsFragmentMode.off)['fragment'], isNull);
      expect(outbound(vlessKcp, TlsFragmentMode.tcp)['fragment'], isNull);
      expect(
        outbound(vlessXhttpReality, TlsFragmentMode.tcp)['fragment'],
        isNull,
      );
    });

    test('WireGuard goes to endpoints', () {
      final config = const SingBoxConfigBuilder(
        options: CoreOptions(),
        platform: CorePlatform.android,
      ).build(LinkParser.parse(wireguard));
      expect(_list(config['endpoints']).single['tag'], 'proxy');
      expect(_list(config['outbounds']).map((o) => o['tag']), ['direct']);
    });

    test('auto mode puts every candidate behind a urltest group', () {
      final config =
          const SingBoxConfigBuilder(
            options: CoreOptions(),
            platform: CorePlatform.android,
          ).buildAuto([
            LinkParser.parse(vlessReality),
            LinkParser.parse(wireguard),
            LinkParser.parse(hy2),
          ]);
      final outbounds = _list(config['outbounds']);
      expect(outbounds.map((o) => o['tag']), [
        'proxy',
        'auto-0',
        'auto-2',
        'direct',
      ]);
      final group = outbounds.first;
      expect(group['type'], 'urltest');
      expect(group['outbounds'], ['auto-0', 'auto-1', 'auto-2']);
      expect(group['url'], SingBoxConfigBuilder.defaultTestUrl);
      expect(group['interval'], '60s');
      expect(group['tolerance'], 150);
      expect(group['interrupt_exist_connections'], isTrue);
      expect(_list(config['endpoints']).single['tag'], 'auto-1');
      expect(_map(config['route'])['final'], 'proxy');
      // The default fingerprint still reaches TLS candidates.
      expect(_map(_map(outbounds[1]['tls'])['utls'])['fingerprint'], isNotNull);
    });

    test('Iranian sites go direct unless disabled', () {
      Map<String, Object?> build(CoreOptions options) => SingBoxConfigBuilder(
        options: options,
        platform: CorePlatform.android,
      ).build(LinkParser.parse(trojanBare));

      final config = build(const CoreOptions());
      final route = _map(config['route']);
      final rules = _list(route['rules']);
      expect(rules.where((r) => r['rule_set'] != null).single, {
        'rule_set': ['iran-domains', 'iran-ips'],
        'outbound': 'direct',
      });
      final sets = {for (final s in _list(route['rule_set'])) s['tag']: s};
      final domains = _list(sets['iran-domains']!['rules']).single;
      expect(domains['domain_suffix'], contains('ir'));
      final cidrs =
          (_list(sets['iran-ips']!['rules']).single['ip_cidr']! as List)
              .cast<String>();
      expect(cidrs, contains('2.176.0.0/12'));
      // IPv6 ranges only when IPv6 is routed at all.
      expect(cidrs.where((c) => c.contains(':')), isEmpty);
      expect(_list(_map(config['dns'])['rules']).single, {
        'rule_set': ['iran-domains'],
        'server': 'dns-direct',
      });

      final v6 = build(const CoreOptions(enableIpv6: true));
      final v6Sets = _list(_map(v6['route'])['rule_set']);
      expect(
        (_list(v6Sets.last['rules']).single['ip_cidr']! as List).any(
          (c) => (c as String).contains(':'),
        ),
        isTrue,
      );

      final off = build(const CoreOptions(bypassIran: false));
      expect(_map(off['route']).containsKey('rule_set'), isFalse);
      expect(_map(off['dns']).containsKey('rules'), isFalse);
      expect(
        _list(_map(off['route'])['rules']).where((r) => r['rule_set'] != null),
        isEmpty,
      );
    });

    test('ads are blocked only when asked', () {
      Map<String, Object?> build(CoreOptions options) => SingBoxConfigBuilder(
        options: options,
        platform: CorePlatform.android,
      ).build(LinkParser.parse(trojanBare));

      bool blocksAds(Map<String, Object?> r) =>
          (r['rule_set'] as List?)?.contains('block-ads') ?? false;

      // Off by default: nothing about ads in the route.
      final off = _map(build(const CoreOptions())['route']);
      expect(_list(off['rules']).where(blocksAds), isEmpty);
      expect(
        _list(off['rule_set']).where((s) => s['tag'] == 'block-ads'),
        isEmpty,
      );

      // On: a reject rule for the ad rule set, and the inline set itself.
      final on = _map(build(const CoreOptions(blockAds: true))['route']);
      expect(_list(on['rules']).singleWhere(blocksAds)['action'], 'reject');
      final adSet = _list(
        on['rule_set'],
      ).singleWhere((s) => s['tag'] == 'block-ads');
      expect(adSet['type'], 'inline');
      expect(
        _list(adSet['rules']).single['domain_suffix'],
        contains('doubleclick.net'),
      );

      // Works on its own, without the Iran rule set.
      final noIran = _map(
        build(const CoreOptions(bypassIran: false, blockAds: true))['route'],
      );
      expect(
        _list(noIran['rule_set']).map((s) => s['tag']),
        ['block-ads'],
      );
    });

    test('TLS fragment and mux go only where they apply', () {
      Map<String, Object?> outbound(String link, CoreOptions options) =>
          prepareOutbound(
            LinkParser.parse(link),
            tag: 'proxy',
            options: options,
          );
      Map<String, Object?> tls(Map<String, Object?> o) => _map(o['tls']);

      const record = CoreOptions(tlsFragment: TlsFragmentMode.record);
      expect(tls(outbound(trojanTls, record))['record_fragment'], isTrue);
      expect(tls(outbound(vlessReality, record))['record_fragment'], isTrue);
      const tcp = CoreOptions(tlsFragment: TlsFragmentMode.tcp);
      expect(tls(outbound(vlessWs, tcp))['fragment'], isTrue);
      expect(
        tls(outbound(vlessWs, tcp)).containsKey('record_fragment'),
        isFalse,
      );
      // TLS inside QUIC and non-TLS protocols are left alone.
      expect(tls(outbound(hy2, tcp)).containsKey('fragment'), isFalse);
      expect(outbound(ssSip002, tcp).containsKey('tls'), isFalse);
      // Off by default.
      expect(
        tls(outbound(trojanTls, const CoreOptions())).keys,
        isNot(contains(anyOf('fragment', 'record_fragment'))),
      );

      const mux = CoreOptions(mux: true, muxProtocol: 'smux');
      for (final link in [vmessWsTls, vlessWs, trojanTls, ss2022]) {
        expect(outbound(link, mux)['multiplex'], {
          'enabled': true,
          'protocol': 'smux',
        }, reason: link);
      }
      // XTLS Vision cannot be multiplexed; QUIC/UDP protocols have no mux.
      for (final link in [vlessReality, hy2, tuic, anytls]) {
        expect(
          outbound(link, mux).containsKey('multiplex'),
          isFalse,
          reason: link,
        );
      }
      expect(
        outbound(trojanTls, const CoreOptions()).containsKey('multiplex'),
        isFalse,
      );
    });

    test('per-app split tunnel only on Android', () {
      Map<String, Object?> tun(CorePlatform platform, CoreOptions options) =>
          _list(
            SingBoxConfigBuilder(
              options: options,
              platform: platform,
            ).build(LinkParser.parse(trojanBare))['inbounds'],
          ).first;

      const include = CoreOptions(
        perAppMode: PerAppMode.include,
        perAppPackages: ['org.telegram.messenger'],
      );
      expect(tun(CorePlatform.android, include)['include_package'], [
        'org.telegram.messenger',
      ]);
      expect(
        tun(
          CorePlatform.android,
          include.copyWith(perAppMode: PerAppMode.exclude),
        )['exclude_package'],
        ['org.telegram.messenger'],
      );
      expect(
        tun(CorePlatform.windows, include).keys,
        isNot(contains('include_package')),
      );
      expect(
        tun(
          CorePlatform.android,
          include.copyWith(perAppMode: PerAppMode.off),
        ).keys,
        isNot(anyOf(contains('include_package'), contains('exclude_package'))),
      );
      // An empty list must not lock every app out of the tunnel.
      expect(
        tun(
          CorePlatform.android,
          const CoreOptions(perAppMode: PerAppMode.include),
        ).keys,
        isNot(contains('include_package')),
      );
    });

    test('QUIC to proxied sites is rejected, after the direct rules', () {
      final rules = _list(
        _map(
          const SingBoxConfigBuilder(
            options: CoreOptions(),
            platform: CorePlatform.android,
          ).build(LinkParser.parse(trojanBare))['route'],
        )['rules'],
      );
      final quic = rules.indexWhere((r) => r['action'] == 'reject');
      final iran = rules.indexWhere((r) => r['rule_set'] != null);
      expect(rules[quic], {'network': 'udp', 'port': 443, 'action': 'reject'});
      expect(quic, greaterThan(iran));
      expect(quic, rules.length - 1);

      final allowed = _list(
        _map(
          const SingBoxConfigBuilder(
            options: CoreOptions(blockQuic: false),
            platform: CorePlatform.android,
          ).build(LinkParser.parse(trojanBare))['route'],
        )['rules'],
      );
      expect(allowed.where((r) => r['action'] == 'reject'), isEmpty);
    });

    test('VLESS and VMess send UDP as xudp unless the link says otherwise', () {
      Map<String, Object?> out(String link) => prepareOutbound(
        LinkParser.parse(link),
        tag: 'proxy',
        options: const CoreOptions(),
      );
      expect(out(vlessWs)['packet_encoding'], 'xudp');
      expect(out(vmessWsTls)['packet_encoding'], 'xudp');
      expect(
        out(
          vlessWs.replaceFirst('#', '&packetEncoding=packetaddr#'),
        )['packet_encoding'],
        'packetaddr',
      );
      expect(out(trojanTls).containsKey('packet_encoding'), isFalse);
    });

    test('auto tags round trip', () {
      expect(
        SingBoxConfigBuilder.autoIndexOf(SingBoxConfigBuilder.autoTag(7)),
        7,
      );
      expect(SingBoxConfigBuilder.autoIndexOf('proxy'), isNull);
      expect(SingBoxConfigBuilder.autoIndexOf('auto-x'), isNull);
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
      bypassIran: false,
    );
    final restored = CoreOptions.fromJson(options.toJson());
    expect(restored, options);
    expect(restored.bypassIran, isFalse);
    expect(CoreOptions.fromJson(const {}).blockQuic, isTrue);
    expect(
      CoreOptions.fromJson(const CoreOptions(blockQuic: false).toJson())
          .blockQuic,
      isFalse,
    );
    const hardened = CoreOptions(
      tlsFragment: TlsFragmentMode.tcp,
      mux: true,
      muxProtocol: 'yamux',
      perAppMode: PerAppMode.exclude,
      perAppPackages: ['com.example.bank'],
    );
    expect(CoreOptions.fromJson(hardened.toJson()), hardened);
    expect(
      CoreOptions.fromJson(const {'muxProtocol': 'bogus', 'tlsFragment': 'x'}),
      const CoreOptions(),
    );
    // Settings saved before the option existed keep the default.
    expect(CoreOptions.fromJson(const {}).bypassIran, isTrue);
    expect(CoreOptions.fromJson(const {}).mixedAuth, isTrue);
    const locked = CoreOptions(mixedPort: 2080, mixedPassword: 'pw');
    expect(CoreOptions.fromJson(locked.toJson()), locked);
    expect(locked.mixedCredentials, (username: 'aghelan', password: 'pw'));
    expect(restored.copyWith(mixedPort: () => null).mixedPort, isNull);
  });
}

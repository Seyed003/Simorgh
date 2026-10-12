import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();

void main() {
  group('VMess', () {
    test('v2rayN JSON with ws + tls + early data', () {
      final p = LinkParser.parse(vmessWsTls);
      expect(p.protocol, ProxyProtocol.vmess);
      expect(p.name, '🇩🇪 Germany WS');
      expect(p.server, 'de.example.com');
      expect(p.port, 443);
      expect(p.outbound, {
        'type': 'vmess',
        'server': 'de.example.com',
        'server_port': 443,
        'uuid': uuid,
        'security': 'auto',
        'alter_id': 0,
        'tls': {
          'enabled': true,
          'server_name': 'cdn.example.com',
          'alpn': ['h2', 'http/1.1'],
          'utls': {'enabled': true, 'fingerprint': 'firefox'},
        },
        'transport': {
          'type': 'ws',
          'max_early_data': 2048,
          'early_data_header_name': 'Sec-WebSocket-Protocol',
          'path': '/ws',
          'headers': {'Host': 'cdn.example.com'},
        },
      });
      expect(p.link, vmessWsTls);
    });

    test('numeric port/aid and grpc service name from path', () {
      final p = LinkParser.parse(vmessGrpc);
      expect(p.port, 8443);
      expect(p.outbound['transport'], {
        'type': 'grpc',
        'service_name': 'my-service',
      });
      expect(_map(p.outbound['tls'])['server_name'], 'grpc.example.com');
    });

    test('tcp with http header obfuscation', () {
      final p = LinkParser.parse(vmessTcpHttp);
      expect(p.outbound['security'], 'aes-128-gcm');
      expect(p.outbound.containsKey('tls'), isFalse);
      expect(p.outbound['transport'], {
        'type': 'http',
        'host': ['a.example.com', 'b.example.com'],
        'path': '/x',
        'method': 'GET',
      });
    });

    test('Xray URL format', () {
      final p = LinkParser.parse(vmessUrl);
      expect(p.name, 'VMess URL');
      expect(p.outbound['transport'], {
        'type': 'httpupgrade',
        'host': 'vm.example.com',
        'path': '/up',
      });
    });

    test('rejects missing id', () {
      expect(
        () => LinkParser.parse(vmessJson({'add': 'a.com', 'port': '1'})),
        throwsA(isA<LinkParseException>()),
      );
    });
  });

  group('VLESS', () {
    test('REALITY + vision', () {
      final p = LinkParser.parse(vlessReality);
      expect(p.name, 'Reality 🇳🇱');
      expect(p.outbound, {
        'type': 'vless',
        'server': '1.2.3.4',
        'server_port': 443,
        'uuid': uuid,
        'flow': 'xtls-rprx-vision',
        'tls': {
          'enabled': true,
          'server_name': 'www.microsoft.com',
          'reality': {
            'enabled': true,
            'public_key': realityKey,
            'short_id': '6ba85179e30d4fc2',
          },
          'utls': {'enabled': true, 'fingerprint': 'chrome'},
        },
      });
      expect(p.summary, 'reality · vision');
    });

    test('ws + tls keeps a remark with raw spaces', () {
      final p = LinkParser.parse(vlessWs);
      expect(p.name, 'My Server 1');
      expect(p.outbound['transport'], {
        'type': 'ws',
        'max_early_data': 2560,
        'early_data_header_name': 'Sec-WebSocket-Protocol',
        'path': '/vless',
        'headers': {'Host': 'ws.example.com'},
      });
      expect(_map(p.outbound['tls'])['alpn'], ['http/1.1']);
      expect(_map(p.outbound['tls']).containsKey('utls'), isFalse);
    });

    test('grpc + reality defaults the fingerprint to chrome', () {
      final p = LinkParser.parse(vlessGrpcReality);
      final tls = _map(p.outbound['tls']);
      expect(tls['utls'], {'enabled': true, 'fingerprint': 'chrome'});
      expect(p.outbound['transport'], {
        'type': 'grpc',
        'service_name': 'grpc-svc',
      });
    });

    test('xhttp runs on the Xray engine', () {
      final p = LinkParser.parse(vlessXhttp);
      expect(p.protocol, ProxyProtocol.vless);
      expect(p.outbound['type'], 'xray');
      final xray = _map(p.outbound['xray']);
      expect(xray['protocol'], 'vless');
      expect(_map(xray['settings'])['vnext'], [
        {
          'address': 'example.com',
          'port': 443,
          'users': [
            {'id': uuid, 'encryption': 'none'},
          ],
        },
      ]);
      expect(xray['streamSettings'], {
        'network': 'xhttp',
        'xhttpSettings': {'path': '/x', 'mode': 'auto'},
        'security': 'tls',
        'tlsSettings': {'serverName': 'example.com', 'fingerprint': 'chrome'},
      });
      expect(p.summary, 'xhttp · tls');
      expect(p.isCdnCandidate, isTrue);
    });

    test('xhttp with reality, mode and extra', () {
      final stream = _map(
        _map(
          LinkParser.parse(vlessXhttpReality).outbound['xray'],
        )['streamSettings'],
      );
      expect(stream['xhttpSettings'], {
        'path': '/xh',
        'mode': 'packet-up',
        'extra': {'xPaddingBytes': '100-1000'},
      });
      expect(stream['realitySettings'], {
        'serverName': 'www.microsoft.com',
        'fingerprint': 'chrome',
        'publicKey': realityKey,
        'shortId': '6ba8',
      });
    });

    test('old mKCP header and seed become finalmask', () {
      final vless = _map(
        _map(LinkParser.parse(vlessKcp).outbound['xray'])['streamSettings'],
      );
      expect(vless['finalmask'], {
        'udp': [
          {'type': 'header-srtp'},
          {
            'type': 'mkcp-aes128gcm',
            'settings': {'password': 'abc'},
          },
        ],
      });
      final vmess = LinkParser.parse(vmessKcp);
      final xray = _map(vmess.outbound['xray']);
      expect(xray['protocol'], 'vmess');
      expect(_map(xray['streamSettings'])['finalmask'], {
        'udp': [
          {'type': 'header-wechat'},
          {
            'type': 'mkcp-aes128gcm',
            'settings': {'password': 's33d'},
          },
        ],
      });
      expect(vmess.isCdnCandidate, isFalse);
      expect(
        _map(
          _map(
            LinkParser.parse('vless://$uuid@k.com:1?type=kcp').outbound['xray'],
          )['streamSettings'],
        )['finalmask'],
        {
          'udp': [
            {'type': 'mkcp-original'},
          ],
        },
      );
    });

    test('Xray TLS verifies certificates, pinned or by name', () {
      final xray = _map(LinkParser.parse(trojanXhttp).outbound['xray']);
      final tls = _map(_map(xray['streamSettings'])['tlsSettings']);
      expect(tls.containsKey('allowInsecure'), isFalse);
      expect(tls['pinnedPeerCertSha256'], pinnedCert);
      expect(_map(xray['settings'])['servers'], [
        {'address': 'cdn.example.com', 'port': 443, 'password': 'pass'},
      ]);
    });

    test('VLESS Encryption runs on the Xray engine', () {
      final xray = _map(LinkParser.parse(vlessEncryption).outbound['xray']);
      final user =
          (((_map(xray['settings'])['vnext'] as List).single as Map)['users']
                      as List)
                  .single
              as Map;
      expect(user['encryption'], startsWith('mlkem768x25519plus.native'));
      expect(_map(xray['streamSettings'])['network'], 'raw');
    });

    test('broken Xray-only fields are rejected', () {
      expect(
        () => LinkParser.parse(
          'vless://$uuid@a.com:443?type=xhttp&extra=%7Bnope',
        ),
        throwsA(isA<LinkParseException>()),
      );
      expect(
        () => LinkParser.parse('vless://$uuid@a.com:1?type=kcp&headerType=x'),
        throwsA(isA<UnsupportedLinkException>()),
      );
    });

    test('clean IP copy of an xhttp config keeps the host name', () {
      final moved = LinkParser.parse(trojanXhttp).withAddress('104.16.1.2');
      final xray = _map(moved.outbound['xray']);
      expect(
        ((_map(xray['settings'])['servers'] as List).single as Map)['address'],
        '104.16.1.2',
      );
      final stream = _map(xray['streamSettings']);
      expect(_map(stream['xhttpSettings'])['host'], 'cdn.example.com');
      expect(_map(stream['tlsSettings'])['serverName'], 'cdn.example.com');
      expect(moved.tlsHost, 'cdn.example.com');
    });

    test('reality without public key is rejected', () {
      expect(
        () => LinkParser.parse(
          'vless://$uuid@a.com:443?security=reality&sni=b.com',
        ),
        throwsA(isA<LinkParseException>()),
      );
    });

    test('IPv6 host in brackets', () {
      final p = LinkParser.parse(
        'vless://$uuid@[2001:db8::1]:443?security=none#v6',
      );
      expect(p.server, '2001:db8::1');
      expect(p.port, 443);
    });

    test('scheme is case insensitive', () {
      final p = LinkParser.parse('VLESS://$uuid@a.com:80?type=tcp#x');
      expect(p.protocol, ProxyProtocol.vless);
    });
  });

  group('Trojan', () {
    test('percent-encoded password and insecure flag', () {
      final p = LinkParser.parse(trojanTls);
      expect(p.outbound['password'], 'p@ss+word');
      expect(p.outbound['tls'], {
        'enabled': true,
        'server_name': 'sni.example.com',
        'insecure': true,
      });
      expect(p.isInsecure, isTrue);
      expect(LinkParser.parse(trojanBare).isInsecure, isFalse);
    });

    test('TLS is implied when security is absent', () {
      final p = LinkParser.parse(trojanBare);
      expect(_map(p.outbound['tls'])['server_name'], 't.example.com');
    });
  });

  group('Shadowsocks', () {
    test('SIP002 with base64 user info', () {
      final p = LinkParser.parse(ssSip002);
      expect(p.name, 'SS 1');
      expect(p.outbound, {
        'type': 'shadowsocks',
        'server': '1.2.3.4',
        'server_port': 8388,
        'method': 'aes-256-gcm',
        'password': 'test-password',
      });
    });

    test('2022 cipher with plain user info', () {
      final p = LinkParser.parse(ss2022);
      expect(p.outbound['method'], '2022-blake3-aes-256-gcm');
      expect(
        p.outbound['password'],
        'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY=',
      );
    });

    test('legacy fully base64 encoded link', () {
      final p = LinkParser.parse(ssLegacy);
      expect(p.server, '5.6.7.8');
      expect(p.port, 8443);
      expect(p.outbound['method'], 'chacha20-ietf-poly1305');
      expect(p.outbound['password'], 'legacy-pass');
      expect(p.name, 'Legacy');
    });

    test('obfs plugin', () {
      final p = LinkParser.parse(ssObfs);
      expect(p.outbound['plugin'], 'obfs-local');
      expect(p.outbound['plugin_opts'], 'obfs=http;obfs-host=example.com');
    });

    test('unknown cipher is unsupported', () {
      expect(
        () => LinkParser.parse('ss://Zm9vOmJhcg@1.2.3.4:1#x'),
        throwsA(isA<UnsupportedLinkException>()),
      );
    });
  });

  group('Hysteria2', () {
    test('obfs + insecure', () {
      final p = LinkParser.parse(hy2);
      expect(p.outbound, {
        'type': 'hysteria2',
        'server': 'hy2.example.com',
        'server_port': 443,
        'password': 'letmein',
        'obfs': {'type': 'salamander', 'password': 'gawrgura'},
        'tls': {
          'enabled': true,
          'server_name': 'real.example.com',
          'insecure': true,
        },
      });
    });

    test('port hopping', () {
      final p = LinkParser.parse(hy2Hopping);
      expect(p.protocol, ProxyProtocol.hysteria2);
      expect(p.port, 443);
      expect(p.outbound['server_ports'], ['443:443', '20000:30000']);
    });

    test('default port is 443', () {
      expect(
        LinkParser.parse('hy2://pw@a.example.com/?sni=a.example.com').port,
        443,
      );
    });
  });

  test('TUIC', () {
    final p = LinkParser.parse(tuic);
    expect(p.outbound, {
      'type': 'tuic',
      'server': 'tuic.example.com',
      'server_port': 443,
      'uuid': uuid,
      'password': 'pass!',
      'congestion_control': 'bbr',
      'udp_relay_mode': 'native',
      'tls': {
        'enabled': true,
        'server_name': 'tuic.example.com',
        'insecure': true,
        'alpn': ['h3'],
      },
    });
  });

  test('WireGuard becomes an endpoint and keeps raw + in keys', () {
    final p = LinkParser.parse(wireguard);
    expect(p.protocol.isEndpoint, isTrue);
    expect(p.name, 'WARP');
    expect(p.outbound, {
      'type': 'wireguard',
      'address': ['172.16.0.2/32', '2606:4700:110:8a36::2/128'],
      'private_key': wgPrivate,
      'peers': [
        {
          'address': '162.159.192.1',
          'port': 2408,
          'public_key': wgPublic,
          'allowed_ips': ['0.0.0.0/0', '::/0'],
          'pre_shared_key': wgPsk,
          'reserved': [78, 135, 76],
        },
      ],
      'mtu': 1280,
    });
  });

  test('SSH', () {
    final p = LinkParser.parse(ssh);
    expect(p.outbound, {
      'type': 'ssh',
      'server': 'ssh.example.com',
      'server_port': 2222,
      'user': 'root',
      'password': 's3cret',
      'host_key': [
        'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwNen5qE5DJI4wh65OEa4rohK1qa+wlEmdDQZHW29SZ',
      ],
    });
  });

  test('Hysteria v1', () {
    final p = LinkParser.parse(hysteria1);
    expect(p.outbound['up_mbps'], 50);
    expect(p.outbound['down_mbps'], 100);
    expect(p.outbound['auth_str'], 'pw');
    expect(p.outbound['obfs'], 'xyz');
    expect(_map(p.outbound['tls'])['alpn'], ['hysteria']);
  });

  test('AnyTLS', () {
    final p = LinkParser.parse(anytls);
    expect(p.outbound['password'], 'pw');
    expect(_map(p.outbound['tls'])['insecure'], true);
  });

  test('SOCKS with base64 credentials', () {
    final p = LinkParser.parse(socks);
    expect(p.outbound, {
      'type': 'socks',
      'server': '1.2.3.4',
      'server_port': 1080,
      'version': '5',
      'username': 'user',
      'password': 'pass',
    });
  });

  group('errors', () {
    test('unknown scheme', () {
      expect(
        () => LinkParser.parse('ssr://abc'),
        throwsA(isA<UnsupportedLinkException>()),
      );
    });

    test('not a link', () {
      expect(
        () => LinkParser.parse('hello'),
        throwsA(isA<LinkParseException>()),
      );
    });

    test('bad port', () {
      expect(
        () => LinkParser.parse('trojan://pw@a.com:99999#x'),
        throwsA(isA<LinkParseException>()),
      );
    });

    test('every fixture parses', () {
      for (final link in allValidLinks) {
        expect(LinkParser.isShareLink(link), isTrue, reason: link);
        expect(() => LinkParser.parse(link), returnsNormally, reason: link);
      }
    });
  });

  test('ProxyConfig JSON round trip', () {
    final p = LinkParser.parse(vlessReality);
    final restored = ProxyConfig.fromJson(p.toJson());
    expect(restored.toJson(), p.toJson());
  });
}

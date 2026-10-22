import 'dart:convert';

const uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';
const realityKey = 'SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc';
const wgPrivate = '1zmVq916+q9+h7Q2BlJkOrlf6MUPkbHQrJoLjjS8kfE=';
const wgPublic = 'uZ4AiUDnzAXMHQsvVNKLcjnA/MLQyVDisQ25DRq+V4g=';
const wgPsk = 'Jz3UXSj+uk5J4F28rNGplB+M8hjXOwjCnPW9RODaR2k=';

String vmessJson(Map<String, Object?> json) =>
    'vmess://${base64.encode(utf8.encode(jsonEncode(json)))}';

final vmessWsTls = vmessJson({
  'v': '2',
  'ps': '🇩🇪 Germany WS',
  'add': 'de.example.com',
  'port': '443',
  'id': uuid,
  'aid': '0',
  'scy': 'auto',
  'net': 'ws',
  'type': 'none',
  'host': 'cdn.example.com',
  'path': '/ws?ed=2048',
  'tls': 'tls',
  'sni': 'cdn.example.com',
  'alpn': 'h2,http/1.1',
  'fp': 'firefox',
});

final vmessGrpc = vmessJson({
  'v': '2',
  'ps': 'gRPC',
  'add': '1.2.3.4',
  'port': 8443,
  'id': uuid,
  'aid': 0,
  'net': 'grpc',
  'path': 'my-service',
  'tls': 'tls',
  'sni': 'grpc.example.com',
});

final vmessTcpHttp = vmessJson({
  'v': '2',
  'ps': 'tcp-http',
  'add': '1.2.3.4',
  'port': '80',
  'id': uuid,
  'aid': '0',
  'scy': 'aes-128-gcm',
  'net': 'tcp',
  'type': 'http',
  'host': 'a.example.com,b.example.com',
  'path': '/x',
  'tls': '',
});

const vmessUrl =
    'vmess://$uuid@vm.example.com:443?encryption=auto&security=tls&sni=vm.example.com&type=httpupgrade&host=vm.example.com&path=%2Fup#VMess%20URL';

const vlessReality =
    'vless://$uuid@1.2.3.4:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=$realityKey&sid=6ba85179e30d4fc2&spx=%2F&type=tcp&headerType=none#Reality%20%F0%9F%87%B3%F0%9F%87%B1';

const vlessWs =
    'vless://$uuid@example.com:443?encryption=none&security=tls&sni=example.com&alpn=http%2F1.1&type=ws&host=ws.example.com&path=%2Fvless%3Fed%3D2560#My Server 1';

const vlessGrpcReality =
    'vless://$uuid@5.6.7.8:2053?security=reality&sni=yahoo.com&pbk=$realityKey&sid=ab&type=grpc&serviceName=grpc-svc&mode=gun#grpc-reality';

const vlessXhttp =
    'vless://$uuid@example.com:443?security=tls&type=xhttp&path=%2Fx#xhttp';

const vlessXhttpReality =
    'vless://$uuid@1.2.3.4:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=$realityKey&sid=6ba8&type=xhttp&path=%2Fxh&mode=packet-up&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%7D#xhttp-reality';

const vlessKcp =
    'vless://$uuid@kcp.example.com:9000?type=kcp&headerType=srtp&seed=abc#kcp';

/// v2rayN JSON: the mKCP seed is in `path`, the header type in `type`.
final vmessKcp = vmessJson({
  'v': '2',
  'ps': 'kcp',
  'add': 'kcp.example.com',
  'port': '8443',
  'id': uuid,
  'aid': '0',
  'scy': 'auto',
  'net': 'kcp',
  'type': 'wechat-video',
  'path': 's33d',
  'tls': '',
});

const trojanXhttp =
    'trojan://pass@cdn.example.com:443?security=tls&sni=cdn.example.com&type=xhttp&host=cdn.example.com&path=%2Ftr&allowInsecure=1&pcs=$pinnedCert#trojan-xhttp';

const pinnedCert =
    '6d2f1d1e3c5a7b9e0f1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f70';

const vlessEncryption =
    'vless://$uuid@enc.example.com:443?encryption=mlkem768x25519plus.native.0rtt.L2GZcKEFIc5MmpwhNQ_hcFT9so-i1IerO3dK5uVIdxA&type=tcp&security=none#vless-enc';

/// Fronted through a CDN: SNI firefox.com, the certificate checked against
/// the CDN's own name (`vcn`), which only Xray can do.
const vlessWsFronted =
    'vless://$uuid@cdn.example.com:443?encryption=none&security=tls&sni=firefox.com&type=ws&host=x.global.ssl.fastly.net&path=%2Fws&vcn=www.fastly.com#fronted';

/// A WARP config as the app builds it (reserved bytes, IPv6, keepalive).
const warpLink =
    'wireguard://$wgPrivate@162.159.192.1:2408?publickey=bmXOC%2BF1FxEMF9dyiK2H5%2F1SUtzH0JuVo51h2wPfgyo%3D&address=172.16.0.2%2F32%2C2606%3A4700%3A110%3A8a36%3A%3A1%2F128&reserved=1,2,3&mtu=1280&keepalive=25#WARP';

const trojanTls =
    'trojan://p%40ss%2Bword@trojan.example.com:443?security=tls&sni=sni.example.com&type=tcp&headerType=none&allowInsecure=1#Trojan';

const trojanBare = 'trojan://secret@t.example.com:8443#bare';

const ssSip002 = 'ss://YWVzLTI1Ni1nY206dGVzdC1wYXNzd29yZA@1.2.3.4:8388#SS%201';

const ss2022 =
    'ss://2022-blake3-aes-256-gcm:YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY%3D@ss.example.com:8443#SS2022';

const ssLegacy =
    'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpsZWdhY3ktcGFzc0A1LjYuNy44Ojg0NDM=#Legacy';

const ssObfs =
    'ss://YWVzLTI1Ni1nY206dGVzdC1wYXNzd29yZA@1.2.3.4:8388/?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dexample.com#obfs';

const hy2 =
    'hysteria2://letmein@hy2.example.com:443/?sni=real.example.com&insecure=1&obfs=salamander&obfs-password=gawrgura#HY2';

const hy2Hopping = 'hy2://pass@1.2.3.4:443,20000-30000/?sni=a.example.com#hop';

const tuic =
    'tuic://$uuid:pass%21@tuic.example.com:443?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=tuic.example.com&allow_insecure=1#TUIC';

const wireguard =
    'wireguard://${'1zmVq916%2Bq9%2Bh7Q2BlJkOrlf6MUPkbHQrJoLjjS8kfE%3D'}@162.159.192.1:2408?publickey=$wgPublic&presharedkey=$wgPsk&address=172.16.0.2%2F32%2C2606%3A4700%3A110%3A8a36%3A%3A2&reserved=78%2C135%2C76&mtu=1280#WARP';

const ssh =
    'ssh://root:s3cret@ssh.example.com:2222?hk=ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5AAAAIBwNen5qE5DJI4wh65OEa4rohK1qa+wlEmdDQZHW29SZ#SSH';

const hysteria1 =
    'hysteria://1.2.3.4:443?protocol=udp&auth=pw&peer=a.example.com&insecure=1&upmbps=50&downmbps=100&obfsParam=xyz#HY1';

const anytls = 'anytls://pw@1.2.3.4:443?sni=a.example.com&insecure=1#AnyTLS';

const socks = 'socks://dXNlcjpwYXNz@1.2.3.4:1080#SOCKS';

const cisco = 'openconnect://bob:pw@vpn.example.com:4443?group=Fast#Cisco';

/// One valid link per supported protocol/variant, used by the sing-box
/// validation test.
final allValidLinks = <String>[
  vmessWsTls,
  vmessGrpc,
  vmessTcpHttp,
  vmessUrl,
  vlessReality,
  vlessWs,
  vlessGrpcReality,
  trojanTls,
  trojanBare,
  ssSip002,
  ss2022,
  ssLegacy,
  ssObfs,
  hy2,
  hy2Hopping,
  tuic,
  wireguard,
  ssh,
  hysteria1,
  anytls,
  socks,
  vlessXhttp,
  vlessXhttpReality,
  vlessKcp,
  vmessKcp,
  trojanXhttp,
  vlessEncryption,
  vlessWsFronted,
  warpLink,
  cisco,
];

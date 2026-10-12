import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses Hysteria v1 links:
/// `hysteria://host:port?protocol=udp&auth=..&peer=..&upmbps=..&downmbps=..`.
ProxyConfig parseHysteria(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.port;
  final protocol = uri.param(['protocol']);
  if (protocol != null && protocol != 'udp') {
    throw UnsupportedLinkException(
      'hysteria protocol "$protocol" is not supported',
    );
  }

  final outbound = <String, Object?>{
    'type': 'hysteria',
    'server': uri.host,
    'server_port': port,
    'up_mbps': int.tryParse(uri.param(['upmbps', 'up']) ?? '') ?? 50,
    'down_mbps': int.tryParse(uri.param(['downmbps', 'down']) ?? '') ?? 100,
  };
  final auth = uri.param(['auth', 'auth_str']);
  if (auth != null) outbound['auth_str'] = auth;
  final obfs = uri.param(['obfsparam', 'obfs-password']);
  if (obfs != null) outbound['obfs'] = obfs;

  final alpn = splitList(uri.param(['alpn']));
  outbound['tls'] = {
    'enabled': true,
    'server_name': uri.param(['peer', 'sni']) ?? uri.host,
    if (uri.flag(['insecure', 'allowinsecure'])) 'insecure': true,
    'alpn': alpn.isEmpty ? ['hysteria'] : alpn,
  };

  return ProxyConfig(
    protocol: ProxyProtocol.hysteria,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'Hysteria ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}

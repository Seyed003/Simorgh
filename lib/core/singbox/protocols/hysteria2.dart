import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

final _leadingInt = RegExp(r'^\d+');

/// Parses `hysteria2://auth@host:port/?sni=..&obfs=salamander#name` (and
/// `hy2://`), including port hopping specs like `host:443,20000-30000`.
ProxyConfig parseHysteria2(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);

  final ports = _parsePorts(uri.portSpec, uri.param(['mport']));
  final port = ports.mainPort;

  final outbound = <String, Object?>{
    'type': 'hysteria2',
    'server': uri.host,
    'server_port': port,
  };
  if (ports.ranges.isNotEmpty) outbound['server_ports'] = ports.ranges;
  final hop = uri.param(['hop_interval', 'hopinterval']);
  if (hop != null && ports.ranges.isNotEmpty) {
    outbound['hop_interval'] = int.tryParse(hop) != null ? '${hop}s' : hop;
  }

  final password = uri.decodedUserInfo ?? uri.param(['auth', 'password']);
  if (password != null && password.isNotEmpty) outbound['password'] = password;

  final up = _mbps(uri.param(['upmbps', 'up']));
  final down = _mbps(uri.param(['downmbps', 'down']));
  if (up != null) outbound['up_mbps'] = up;
  if (down != null) outbound['down_mbps'] = down;

  final obfs = uri.param(['obfs']);
  if (obfs != null && obfs != 'none') {
    if (obfs != 'salamander') {
      throw UnsupportedLinkException('unsupported hysteria2 obfs "$obfs"');
    }
    outbound['obfs'] = {
      'type': 'salamander',
      'password':
          uri.param(['obfs-password', 'obfs_password', 'obfspassword']) ?? '',
    };
  }

  final alpn = splitList(uri.param(['alpn']));
  outbound['tls'] = {
    'enabled': true,
    'server_name': uri.param(['sni', 'peer']) ?? uri.host,
    if (uri.flag(['insecure', 'allowinsecure'])) 'insecure': true,
    if (alpn.isNotEmpty) 'alpn': alpn,
  };

  return ProxyConfig(
    protocol: ProxyProtocol.hysteria2,
    name: uri.fragment.isNotEmpty
        ? uri.fragment
        : 'Hysteria2 ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}

int? _mbps(String? value) {
  if (value == null) return null;
  final match = _leadingInt.firstMatch(value.trim());
  return match == null ? null : int.parse(match.group(0)!);
}

class _Ports {
  const _Ports(this.mainPort, this.ranges);

  final int mainPort;

  /// sing-box `server_ports` entries (`start:end`), empty without hopping.
  final List<String> ranges;
}

_Ports _parsePorts(String spec, String? mport) {
  final all = [
    ...spec.split(','),
    if (mport != null) ...mport.split(','),
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (all.isEmpty) return const _Ports(443, []);
  if (all.length == 1 && !all.first.contains('-')) {
    final port = int.tryParse(all.first);
    if (port == null || port <= 0 || port > 65535) {
      throw LinkParseException('invalid port "$spec"');
    }
    return _Ports(port, const []);
  }

  final ranges = <String>[];
  int? first;
  for (final part in all) {
    final bounds = part.split('-');
    final start = int.tryParse(bounds.first);
    final end = bounds.length > 1 ? int.tryParse(bounds[1]) : start;
    if (start == null ||
        end == null ||
        start <= 0 ||
        end > 65535 ||
        start > end) {
      throw LinkParseException('invalid port range "$part"');
    }
    first ??= start;
    ranges.add('$start:$end');
  }
  return _Ports(first!, ranges);
}

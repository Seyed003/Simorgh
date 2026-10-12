import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

const _congestionControls = {'cubic', 'new_reno', 'bbr'};

/// Parses `tuic://uuid:password@host:port?congestion_control=bbr&alpn=h3#name`.
ProxyConfig parseTuic(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.port;
  final userInfo = uri.decodedUserInfo ?? '';
  final colon = userInfo.indexOf(':');
  final uuid = colon >= 0 ? userInfo.substring(0, colon) : userInfo;
  final password = colon >= 0
      ? userInfo.substring(colon + 1)
      : uri.param(['password']);
  if (uuid.isEmpty) throw const LinkParseException('missing tuic uuid');

  final outbound = <String, Object?>{
    'type': 'tuic',
    'server': uri.host,
    'server_port': port,
    'uuid': uuid,
    if (password != null && password.isNotEmpty) 'password': password,
  };
  final cc = uri.param([
    'congestion_control',
    'congestion-control',
    'cc',
  ])?.toLowerCase();
  if (cc != null && _congestionControls.contains(cc)) {
    outbound['congestion_control'] = cc;
  }
  final relay = uri.param(['udp_relay_mode', 'udp-relay-mode'])?.toLowerCase();
  if (relay == 'native' || relay == 'quic') outbound['udp_relay_mode'] = relay;
  if (uri.flag(['reduce_rtt', 'zero_rtt_handshake', 'zero-rtt'])) {
    outbound['zero_rtt_handshake'] = true;
  }

  final alpn = splitList(uri.param(['alpn']));
  final disableSni = uri.flag(['disable_sni', 'disable-sni']);
  outbound['tls'] = {
    'enabled': true,
    if (disableSni) 'disable_sni': true,
    'server_name': uri.param(['sni', 'peer']) ?? uri.host,
    if (uri.flag(['allow_insecure', 'allowinsecure', 'insecure']))
      'insecure': true,
    'alpn': alpn.isEmpty ? ['h3'] : alpn,
  };

  return ProxyConfig(
    protocol: ProxyProtocol.tuic,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'TUIC ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}

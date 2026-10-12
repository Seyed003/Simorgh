import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses `ssh://user:password@host:port?pk=<private key>&hk=<host key>#name`.
ProxyConfig parseSsh(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.portSpec.isEmpty ? 22 : uri.port;
  final userInfo = uri.decodedUserInfo ?? '';
  final colon = userInfo.indexOf(':');
  final user = colon >= 0 ? userInfo.substring(0, colon) : userInfo;
  final password = colon >= 0
      ? userInfo.substring(colon + 1)
      : uri.param(['password']);

  final outbound = <String, Object?>{
    'type': 'ssh',
    'server': uri.host,
    'server_port': port,
    'user': user.isEmpty ? 'root' : user,
    if (password != null && password.isNotEmpty) 'password': password,
  };
  final privateKey = uri.param(['pk', 'private_key', 'privatekey']);
  if (privateKey != null) outbound['private_key'] = privateKey;
  final passphrase = uri.param(['pkp', 'passphrase', 'private_key_passphrase']);
  if (passphrase != null) outbound['private_key_passphrase'] = passphrase;
  final hostKeys = splitList(uri.param(['hk', 'host_key', 'hostkey']));
  if (hostKeys.isNotEmpty) outbound['host_key'] = hostKeys;
  final clientVersion = uri.param(['client_version', 'cv']);
  if (clientVersion != null) outbound['client_version'] = clientVersion;

  if (password == null && privateKey == null) {
    throw const LinkParseException('ssh link needs a password or private key');
  }

  return ProxyConfig(
    protocol: ProxyProtocol.ssh,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'SSH ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}

import 'protocols/anytls.dart';
import 'protocols/hysteria.dart';
import 'protocols/hysteria2.dart';
import 'protocols/shadowsocks.dart';
import 'protocols/socks.dart';
import 'protocols/ssh.dart';
import 'protocols/trojan.dart';
import 'protocols/tuic.dart';
import 'protocols/vless.dart';
import 'protocols/vmess.dart';
import 'protocols/wireguard.dart';
import 'proxy_config.dart';

typedef _Parser = ProxyConfig Function(String link);

const Map<String, _Parser> _parsers = {
  'vmess': parseVmess,
  'vless': parseVless,
  'trojan': parseTrojan,
  'ss': parseShadowsocks,
  'hysteria2': parseHysteria2,
  'hy2': parseHysteria2,
  'hysteria': parseHysteria,
  'tuic': parseTuic,
  'wireguard': parseWireGuard,
  'wg': parseWireGuard,
  'ssh': parseSsh,
  'anytls': parseAnyTls,
  'socks': parseSocks,
  'socks5': parseSocks,
  'socks4': parseSocks,
  'socks4a': parseSocks,
};

/// Converts a single share link into a [ProxyConfig].
abstract final class LinkParser {
  static Iterable<String> get supportedSchemes => _parsers.keys;

  /// Whether [line] starts with a scheme this parser understands.
  static bool isShareLink(String line) {
    final scheme = _schemeOf(line.trim());
    return scheme != null && _parsers.containsKey(scheme);
  }

  /// Parses [link] or throws a [LinkParseException].
  static ProxyConfig parse(String link) {
    final trimmed = link.trim();
    final scheme = _schemeOf(trimmed);
    if (scheme == null) throw const LinkParseException('not a share link');
    final parser = _parsers[scheme];
    if (parser == null) {
      throw UnsupportedLinkException('unsupported scheme "$scheme"');
    }
    // Normalise the scheme casing so protocol parsers can rely on it.
    final normalized = '$scheme${trimmed.substring(scheme.length)}';
    try {
      return parser(normalized);
    } on LinkParseException {
      rethrow;
    } on FormatException catch (e) {
      throw LinkParseException(e.message);
    } on RangeError catch (e) {
      throw LinkParseException(e.message.toString());
    }
  }

  static String? _schemeOf(String link) {
    final end = link.indexOf('://');
    if (end <= 0) return null;
    return link.substring(0, end).toLowerCase();
  }
}

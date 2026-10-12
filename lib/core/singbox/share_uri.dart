import 'encoding.dart';
import 'proxy_config.dart';

/// Lenient parser for `scheme://userinfo@host:port/path?query#fragment`.
///
/// [Uri.parse] is too strict for real-world share links: passwords contain
/// raw `+`/`/`, Hysteria2 uses multi-port specs like `443,20000-30000` and
/// many generators skip percent-encoding entirely.
class ShareUri {
  ShareUri._({
    required this.scheme,
    required this.userInfo,
    required this.host,
    required this.portSpec,
    required this.path,
    required this.query,
    required this.fragment,
  });

  final String scheme;

  /// Raw (still percent-encoded) user info, `null` when absent.
  final String? userInfo;
  final String host;

  /// Port as written, may be a multi-port list for Hysteria2.
  final String portSpec;
  final String path;

  /// Query parameters with lower-cased keys and percent-decoded values.
  final Map<String, String> query;

  /// Percent-decoded fragment (the remark).
  final String fragment;

  static ShareUri parse(String link) {
    final schemeEnd = link.indexOf('://');
    if (schemeEnd <= 0) {
      throw const LinkParseException('missing scheme');
    }
    final scheme = link.substring(0, schemeEnd).toLowerCase();
    var rest = link.substring(schemeEnd + 3);

    var fragment = '';
    final hash = rest.indexOf('#');
    if (hash >= 0) {
      fragment = percentDecode(rest.substring(hash + 1)).trim();
      rest = rest.substring(0, hash);
    }

    var queryString = '';
    final question = rest.indexOf('?');
    if (question >= 0) {
      queryString = rest.substring(question + 1);
      rest = rest.substring(0, question);
    }

    String? userInfo;
    final at = rest.lastIndexOf('@');
    if (at >= 0) {
      userInfo = rest.substring(0, at);
      rest = rest.substring(at + 1);
    }

    var path = '';
    final slash = rest.indexOf('/');
    if (slash >= 0) {
      path = rest.substring(slash);
      rest = rest.substring(0, slash);
    }

    String host;
    var portSpec = '';
    if (rest.startsWith('[')) {
      final close = rest.indexOf(']');
      if (close < 0) throw const LinkParseException('unterminated IPv6 host');
      host = rest.substring(1, close);
      final after = rest.substring(close + 1);
      if (after.startsWith(':')) portSpec = after.substring(1);
    } else {
      final colon = rest.lastIndexOf(':');
      if (colon >= 0) {
        host = rest.substring(0, colon);
        portSpec = rest.substring(colon + 1);
      } else {
        host = rest;
      }
    }

    return ShareUri._(
      scheme: scheme,
      userInfo: userInfo,
      host: percentDecode(host),
      portSpec: portSpec,
      path: percentDecode(path),
      query: parseQuery(queryString),
      fragment: fragment,
    );
  }

  /// The single numeric port, throwing when absent or out of range.
  int get port {
    final value = int.tryParse(portSpec);
    if (value == null || value <= 0 || value > 65535) {
      throw LinkParseException('invalid port "$portSpec"');
    }
    return value;
  }

  /// Returns the first non-empty query value among [keys] (case-insensitive).
  String? param(List<String> keys) {
    for (final key in keys) {
      final value = query[key.toLowerCase()];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool flag(List<String> keys) {
    final value = param(keys)?.toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  String? get decodedUserInfo =>
      userInfo == null ? null : percentDecode(userInfo!);
}

/// Splits a query string into lower-cased keys and percent-decoded values.
Map<String, String> parseQuery(String query) {
  final result = <String, String>{};
  for (final part in query.split('&')) {
    if (part.isEmpty) continue;
    final eq = part.indexOf('=');
    final key = percentDecode(eq < 0 ? part : part.substring(0, eq));
    final value = eq < 0 ? '' : percentDecode(part.substring(eq + 1));
    result.putIfAbsent(key.toLowerCase(), () => value);
  }
  return result;
}

void requireHost(String host) {
  if (host.isEmpty) throw const LinkParseException('missing server address');
}

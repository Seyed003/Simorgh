import '../../../core/singbox/subscription_parser.dart';

/// What a tapped link or shared text asks the app to add.
sealed class IncomingImport {
  const IncomingImport();

  /// Understands config links and text, plain subscription URLs, and the
  /// import links of subscription pages:
  ///
  /// - `aghelan://import?url=<subscription>&name=` / `aghelan://add?config=`
  /// - `sing-box://import-remote-profile?url=<subscription>#name`
  /// - `v2rayng://install-sub?url=` / `v2rayng://install-config?url=`
  /// - `hiddify://import/<subscription>#name`
  ///
  /// Returns `null` when there is nothing to add.
  static IncomingImport? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final single = !text.contains(RegExp(r'\s'));
    final uri = single ? Uri.tryParse(text) : null;
    if (uri != null) {
      String? param(String key) {
        final value = uri.queryParameters[key];
        return value == null || value.trim().isEmpty ? null : value.trim();
      }

      String? fragment() =>
          uri.fragment.isEmpty ? null : Uri.decodeComponent(uri.fragment);

      switch (uri.scheme.toLowerCase()) {
        case 'http' || 'https' when uri.host.isNotEmpty:
          return IncomingSubscription(text);
        case 'aghelan':
          if (param('url') case final url?) {
            return IncomingSubscription.orNull(url, name: param('name'));
          }
          if (param('config') case final config?) return parse(config);
          return null;
        case 'sing-box' when uri.host == 'import-remote-profile':
          final url = param('url');
          return url == null
              ? null
              : IncomingSubscription.orNull(url, name: fragment());
        case 'v2rayng':
          final url = param('url');
          if (url == null) return null;
          return uri.host == 'install-sub'
              ? IncomingSubscription.orNull(url, name: param('name'))
              : parse(url);
        case 'hiddify':
          final path = text.substring('hiddify://'.length);
          final withoutPrefix = path.startsWith('import/')
              ? path.substring('import/'.length)
              : path;
          final hash = withoutPrefix.indexOf('#');
          final url = hash < 0
              ? withoutPrefix
              : withoutPrefix.substring(0, hash);
          return IncomingSubscription.orNull(
            Uri.decodeFull(url),
            name: fragment(),
          );
      }
    }
    final count = SubscriptionParser.parse(text).proxies.length;
    return count == 0 ? null : IncomingConfigs(text, count);
  }
}

/// Config links (or a sing-box / Xray JSON) to import as they are.
class IncomingConfigs extends IncomingImport {
  const IncomingConfigs(this.text, this.count);

  final String text;
  final int count;
}

class IncomingSubscription extends IncomingImport {
  const IncomingSubscription(this.url, {this.name});

  final String url;
  final String? name;

  String get host => Uri.tryParse(url)?.host ?? url;

  static IncomingSubscription? orNull(String url, {String? name}) {
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
    return valid ? IncomingSubscription(url, name: name) : null;
  }
}

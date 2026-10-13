/// The address a subscription is downloaded from: an http(s) URL as is,
/// and Outline's dynamic access keys (`ssconf://host/path#name`) over
/// https, as the Outline app fetches them. `null` for anything else.
Uri? subscriptionUri(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
  var uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.isScheme('ssconf')) {
    uri = uri.replace(scheme: 'https').removeFragment();
  }
  return uri.isScheme('http') || uri.isScheme('https') ? uri : null;
}

/// The name an `ssconf://…#name` key carries.
String? subscriptionNameOf(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.isScheme('ssconf') || uri.fragment.isEmpty) {
    return null;
  }
  return Uri.decodeComponent(uri.fragment);
}

/// A subscription fetched over plain http: anyone on the way (the ISP)
/// can read it and swap its configs for their own servers.
bool isPlainHttp(String url) =>
    Uri.tryParse(url.trim())?.isScheme('http') ?? false;

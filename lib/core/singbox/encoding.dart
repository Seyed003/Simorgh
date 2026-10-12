import 'dart:convert';

final _whitespace = RegExp(r'\s+');
final _base64Chars = RegExp(r'^[A-Za-z0-9+/_\-]+=*$');

/// Decodes standard or URL-safe base64, with or without padding and line
/// breaks. Returns `null` when [input] is not base64 or not valid UTF-8.
String? tryDecodeBase64(String input) {
  var s = input.replaceAll(_whitespace, '');
  if (s.isEmpty || !_base64Chars.hasMatch(s)) return null;
  s = s.replaceAll('-', '+').replaceAll('_', '/').replaceAll('=', '');
  final remainder = s.length % 4;
  if (remainder == 1) return null;
  if (remainder > 0) s = s.padRight(s.length + 4 - remainder, '=');
  try {
    return utf8.decode(base64.decode(s));
  } on FormatException {
    return null;
  }
}

/// Percent-decodes [input] without turning `+` into a space. Share links
/// often carry raw base64 keys and passwords where `+` is significant.
String percentDecode(String input) {
  if (!input.contains('%')) return input;
  try {
    return Uri.decodeComponent(input);
  } on ArgumentError {
    return input;
  } on FormatException {
    return input;
  }
}

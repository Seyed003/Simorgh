import 'encoding.dart';

/// Metadata advertised by subscription servers through HTTP headers
/// (`subscription-userinfo`, `profile-title`, `profile-update-interval`).
class SubscriptionInfo {
  const SubscriptionInfo({
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.title,
    this.updateInterval,
    this.supportUrl,
    this.webPageUrl,
  });

  final int upload;
  final int download;

  /// Total quota in bytes, `0` means unlimited.
  final int total;
  final DateTime? expire;
  final String? title;
  final Duration? updateInterval;
  final String? supportUrl;
  final String? webPageUrl;

  int get used => upload + download;

  bool get hasUsage => total > 0 || used > 0;

  /// 2^53: exact as a double, and about 9 PB.
  static const _maxValue = 9007199254740992;

  /// The last second of the year 9999.
  static const _maxExpireSeconds = 253402300799;

  /// Parses response headers (keys must be lower-case, as `package:http`
  /// provides them).
  factory SubscriptionInfo.fromHeaders(Map<String, String> headers) {
    final values = <String, int>{};
    final userInfo = headers['subscription-userinfo'];
    if (userInfo != null) {
      for (final part in userInfo.split(';')) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final number = num.tryParse(kv[1].trim());
        // NaN, infinity or a number beyond any real quota would throw in
        // toInt() / DateTime and stop every other subscription's update.
        if (number == null || !number.isFinite || number < 0) continue;
        values[kv[0].trim().toLowerCase()] = number.clamp(0, _maxValue).toInt();
      }
    }
    final expire = values['expire'];
    final interval = int.tryParse(
      headers['profile-update-interval']?.trim() ?? '',
    );
    return SubscriptionInfo(
      upload: values['upload'] ?? 0,
      download: values['download'] ?? 0,
      total: values['total'] ?? 0,
      expire: expire != null && expire > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              expire.clamp(0, _maxExpireSeconds) * 1000,
              isUtc: true,
            )
          : null,
      title:
          _decodeTitle(headers['profile-title']) ??
          _fileName(headers['content-disposition']),
      updateInterval: interval != null && interval > 0
          ? Duration(hours: interval)
          : null,
      supportUrl: headers['support-url'],
      webPageUrl: headers['profile-web-page-url'],
    );
  }

  Map<String, Object?> toJson() => {
    'upload': upload,
    'download': download,
    'total': total,
    if (expire != null) 'expire': expire!.millisecondsSinceEpoch,
    if (title != null) 'title': title,
    if (updateInterval != null) 'updateIntervalHours': updateInterval!.inHours,
    if (supportUrl != null) 'supportUrl': supportUrl,
    if (webPageUrl != null) 'webPageUrl': webPageUrl,
  };

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) {
    final expire = json['expire'] as int?;
    final hours = json['updateIntervalHours'] as int?;
    return SubscriptionInfo(
      upload: json['upload'] as int? ?? 0,
      download: json['download'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      expire: expire == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expire, isUtc: true),
      title: json['title'] as String?,
      updateInterval: hours == null ? null : Duration(hours: hours),
      supportUrl: json['supportUrl'] as String?,
      webPageUrl: json['webPageUrl'] as String?,
    );
  }

  static String? _decodeTitle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (trimmed.startsWith('base64:')) {
      return tryDecodeBase64(trimmed.substring(7))?.trim();
    }
    return percentDecode(trimmed);
  }

  static String? _fileName(String? disposition) {
    if (disposition == null) return null;
    final star = RegExp(
      r"filename\*=(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (star != null) {
      return percentDecode(star.group(1)!.trim().replaceAll('"', ''));
    }
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain?.group(1)?.trim();
  }
}

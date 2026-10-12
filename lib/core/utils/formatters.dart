import 'package:intl/intl.dart';

const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Human readable byte size, e.g. `1.4 MB`. Digits follow [locale]
/// (`fa` renders Persian digits).
String formatBytes(int bytes, {String? locale}) {
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  final pattern = unit == 0 || value >= 100 ? '#,##0' : '#,##0.#';
  return '${NumberFormat(pattern, locale).format(value)} ${_units[unit]}';
}

/// Transfer rate, e.g. `512 KB/s`.
String formatSpeed(int bytesPerSecond, {String? locale}) =>
    '${formatBytes(bytesPerSecond, locale: locale)}/s';

/// Network speed in megabits per second, e.g. `23.4 Mbps` (whole numbers
/// from 100 Mbps up).
String formatMbps(int bytesPerSecond, {String? locale}) {
  final mbps = bytesPerSecond * 8 / 1e6;
  final pattern = mbps >= 100 ? '#,##0' : '#,##0.#';
  return '${NumberFormat(pattern, locale).format(mbps)} Mbps';
}

/// `HH:MM:SS` with locale digits.
String formatDuration(Duration duration, {String? locale}) {
  final two = NumberFormat('00', locale);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${two.format(hours)}:${two.format(minutes)}:${two.format(seconds)}';
}

/// Localized integer, e.g. Persian digits for `fa`.
String formatNumber(num value, {String? locale}) =>
    NumberFormat.decimalPattern(locale).format(value);

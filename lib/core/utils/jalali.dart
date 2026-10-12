import 'package:intl/intl.dart';

/// Solar Hijri (Jalali) date, the calendar Persian readers expect.
typedef JalaliDate = ({int year, int month, int day});

const _jalaliMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// Converts a Gregorian date (the arithmetic algorithm used by most Iranian
/// software; exact for 1800–2200).
JalaliDate toJalali(DateTime date) {
  const monthStart = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy = date.year;
  final gm = date.month;
  final gd = date.day;
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days =
      355666 +
      365 * gy +
      (gy2 + 3) ~/ 4 -
      (gy2 + 99) ~/ 100 +
      (gy2 + 399) ~/ 400 +
      gd +
      monthStart[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final (jm, jd) = days < 186
      ? (1 + days ~/ 31, 1 + days % 31)
      : (7 + (days - 186) ~/ 30, 1 + (days - 186) % 30);
  return (year: jy, month: jm, day: jd);
}

/// Full date: `20 مهر 1405` in Persian digits for `fa`, `Oct 12, 2026`
/// otherwise.
String formatDate(DateTime date, {String? locale}) {
  if (locale == 'fa') {
    final j = toJalali(date);
    final n = NumberFormat('0', 'fa');
    return '${n.format(j.day)} ${_jalaliMonths[j.month - 1]} ${n.format(j.year)}';
  }
  return DateFormat.yMMMd(locale).format(date);
}

/// Day of the month in the reader's calendar, for chart axes.
String formatDayOfMonth(DateTime date, {String? locale}) {
  if (locale == 'fa') {
    return NumberFormat('0', 'fa').format(toJalali(date).day);
  }
  return NumberFormat('0', locale).format(date.day);
}

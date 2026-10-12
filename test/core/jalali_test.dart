import 'package:aghelan_ghiamat/core/utils/jalali.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('known Gregorian -> Jalali dates', () {
    expect(toJalali(DateTime(1979, 2, 11)), (year: 1357, month: 11, day: 22));
    expect(toJalali(DateTime(2024, 3, 20)), (year: 1403, month: 1, day: 1));
    expect(toJalali(DateTime(2025, 3, 21)), (year: 1404, month: 1, day: 1));
    expect(toJalali(DateTime(2025, 3, 20)), (year: 1403, month: 12, day: 30));
    expect(toJalali(DateTime(2026, 10, 12)), (year: 1405, month: 7, day: 20));
  });

  test('formats in the reader calendar', () {
    expect(formatDate(DateTime(2026, 10, 12), locale: 'fa'), '۲۰ مهر ۱۴۰۵');
    expect(formatDate(DateTime(2026, 10, 12), locale: 'en'), 'Oct 12, 2026');
    expect(formatDayOfMonth(DateTime(2026, 10, 12), locale: 'fa'), '۲۰');
    expect(formatDayOfMonth(DateTime(2026, 10, 12), locale: 'en'), '12');
  });
}

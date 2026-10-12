import 'package:aghelan_ghiamat/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('picks the right unit', () {
      expect(formatBytes(0, locale: 'en'), '0 B');
      expect(formatBytes(1023, locale: 'en'), '1,023 B');
      expect(formatBytes(1536, locale: 'en'), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024, locale: 'en'), '5 MB');
      expect(formatBytes(150 * 1024 * 1024, locale: 'en'), '150 MB');
    });

    test('uses Persian digits for fa', () {
      expect(formatBytes(1536, locale: 'fa'), '۱٫۵ KB');
    });
  });

  test('formatSpeed appends per second', () {
    expect(formatSpeed(2048, locale: 'en'), '2 KB/s');
  });

  test('formatDuration pads fields', () {
    expect(
      formatDuration(
        const Duration(hours: 1, minutes: 2, seconds: 3),
        locale: 'en',
      ),
      '01:02:03',
    );
    expect(
      formatDuration(const Duration(seconds: 65), locale: 'fa'),
      '۰۰:۰۱:۰۵',
    );
  });
}

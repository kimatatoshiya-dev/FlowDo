import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/utils/japanese_holidays.dart';

void main() {
  group('isJapaneseHoliday', () {
    test('元日は祝日', () {
      expect(isJapaneseHoliday(DateTime(2026, 1, 1)), isTrue);
    });

    test('通常の平日は祝日ではない', () {
      expect(isJapaneseHoliday(DateTime(2026, 8, 12)), isFalse);
    });

    test('山の日は祝日', () {
      expect(isJapaneseHoliday(DateTime(2026, 8, 11)), isTrue);
    });
  });
}

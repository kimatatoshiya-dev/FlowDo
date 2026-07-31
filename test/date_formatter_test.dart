import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/utils/date_formatter.dart';

void main() {
  group('DateFormatter.formatDueDate', () {
    final reference = DateTime(2026, 7, 28);

    test('今年の日付は M/D 形式', () {
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 7, 30), reference: reference),
        '7/30',
      );
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 10, 30), reference: reference),
        '10/30',
      );
      expect(
        DateFormatter.formatDueDate(DateTime(2026, 12, 31), reference: reference),
        '12/31',
      );
    });

    test('今年以外は YYYY/M/D 形式', () {
      expect(
        DateFormatter.formatDueDate(DateTime(2027, 1, 5), reference: reference),
        '2027/1/5',
      );
    });
  });
}

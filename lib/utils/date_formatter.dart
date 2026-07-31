/// 日付の表示フォーマット
class DateFormatter {
  DateFormatter._();

  /// 期限未設定時の表示ラベル
  static const noDueDateLabel = '期限なし';

  static String format(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}/$m/$d';
  }

  /// タスク一覧の期限表示（今年は M/D、それ以外は YYYY/M/D）
  static String formatDueDate(DateTime date, {DateTime? reference}) {
    final ref = reference ?? DateTime.now();
    final m = date.month;
    final d = date.day;
    if (date.year == ref.year) {
      return '$m/$d';
    }
    return '${date.year}/$m/$d';
  }

  static String formatDateTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${format(date)} $h:$min';
  }
}

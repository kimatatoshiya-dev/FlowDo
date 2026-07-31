/// 完了タスクの自動削除設定
enum CompletedTaskRetention {
  /// 7日で自動削除（推奨）
  days7,

  /// 30日で自動削除
  days30,

  /// 自動削除しない
  never;

  static const defaults = CompletedTaskRetention.days7;

  String get label => switch (this) {
        CompletedTaskRetention.days7 => '7日で自動削除（推奨）',
        CompletedTaskRetention.days30 => '30日で自動削除',
        CompletedTaskRetention.never => '自動削除しない',
      };

  int? get retentionDays => switch (this) {
        CompletedTaskRetention.days7 => 7,
        CompletedTaskRetention.days30 => 30,
        CompletedTaskRetention.never => null,
      };

  static CompletedTaskRetention fromStorage(String? value) {
    return switch (value) {
      'days30' => CompletedTaskRetention.days30,
      'never' => CompletedTaskRetention.never,
      _ => CompletedTaskRetention.days7,
    };
  }

  String get storageValue => switch (this) {
        CompletedTaskRetention.days7 => 'days7',
        CompletedTaskRetention.days30 => 'days30',
        CompletedTaskRetention.never => 'never',
      };
}

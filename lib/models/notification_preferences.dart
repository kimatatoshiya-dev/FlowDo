/// タスク通知のユーザー設定
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.leadTime = NotificationLeadTime.minutes15,
  });

  static const defaults = NotificationPreferences();

  final bool enabled;
  final NotificationLeadTime leadTime;

  NotificationPreferences copyWith({
    bool? enabled,
    NotificationLeadTime? leadTime,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      leadTime: leadTime ?? this.leadTime,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationPreferences &&
        other.enabled == enabled &&
        other.leadTime == leadTime;
  }

  @override
  int get hashCode => Object.hash(enabled, leadTime);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'leadTime': leadTime.storageValue,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      leadTime: NotificationLeadTime.fromStorage(
        json['leadTime'] as String?,
      ),
    );
  }
}

/// 通知タイミング（期限時刻の何分前に通知するか）
enum NotificationLeadTime {
  none,
  atTime,
  minutes5,
  minutes10,
  minutes15,
  minutes30,
  hour1,
  dayBefore;

  static const defaults = NotificationLeadTime.minutes15;

  String get label => switch (this) {
        NotificationLeadTime.none => 'なし',
        NotificationLeadTime.atTime => '時間ちょうど',
        NotificationLeadTime.minutes5 => '5分前',
        NotificationLeadTime.minutes10 => '10分前',
        NotificationLeadTime.minutes15 => '15分前（デフォルト）',
        NotificationLeadTime.minutes30 => '30分前',
        NotificationLeadTime.hour1 => '1時間前',
        NotificationLeadTime.dayBefore => '前日',
      };

  /// 通知本文用の短い表記（「まであと○○です。」）
  String get bodyLabel => switch (this) {
        NotificationLeadTime.minutes5 => '5分',
        NotificationLeadTime.minutes10 => '10分',
        NotificationLeadTime.minutes15 => '15分',
        NotificationLeadTime.minutes30 => '30分',
        NotificationLeadTime.hour1 => '1時間',
        NotificationLeadTime.dayBefore => '1日',
        NotificationLeadTime.none ||
        NotificationLeadTime.atTime =>
          '',
      };

  Duration? get leadDuration => switch (this) {
        NotificationLeadTime.none => null,
        NotificationLeadTime.atTime => Duration.zero,
        NotificationLeadTime.minutes5 => const Duration(minutes: 5),
        NotificationLeadTime.minutes10 => const Duration(minutes: 10),
        NotificationLeadTime.minutes15 => const Duration(minutes: 15),
        NotificationLeadTime.minutes30 => const Duration(minutes: 30),
        NotificationLeadTime.hour1 => const Duration(hours: 1),
        NotificationLeadTime.dayBefore => const Duration(days: 1),
      };

  static NotificationLeadTime fromStorage(String? value) {
    return switch (value) {
      'none' => NotificationLeadTime.none,
      'atTime' => NotificationLeadTime.atTime,
      'minutes5' => NotificationLeadTime.minutes5,
      'minutes10' => NotificationLeadTime.minutes10,
      'minutes30' => NotificationLeadTime.minutes30,
      'hour1' => NotificationLeadTime.hour1,
      'dayBefore' => NotificationLeadTime.dayBefore,
      _ => NotificationLeadTime.minutes15,
    };
  }

  String get storageValue => switch (this) {
        NotificationLeadTime.none => 'none',
        NotificationLeadTime.atTime => 'atTime',
        NotificationLeadTime.minutes5 => 'minutes5',
        NotificationLeadTime.minutes10 => 'minutes10',
        NotificationLeadTime.minutes15 => 'minutes15',
        NotificationLeadTime.minutes30 => 'minutes30',
        NotificationLeadTime.hour1 => 'hour1',
        NotificationLeadTime.dayBefore => 'dayBefore',
      };
}

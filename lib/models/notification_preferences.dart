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
  minutes5,
  minutes15,
  minutes30,
  hour1;

  static const defaults = NotificationLeadTime.minutes15;

  String get label => switch (this) {
        NotificationLeadTime.none => 'なし',
        NotificationLeadTime.minutes5 => '5分前',
        NotificationLeadTime.minutes15 => '15分前（デフォルト）',
        NotificationLeadTime.minutes30 => '30分前',
        NotificationLeadTime.hour1 => '1時間前',
      };

  Duration? get leadDuration => switch (this) {
        NotificationLeadTime.none => null,
        NotificationLeadTime.minutes5 => const Duration(minutes: 5),
        NotificationLeadTime.minutes15 => const Duration(minutes: 15),
        NotificationLeadTime.minutes30 => const Duration(minutes: 30),
        NotificationLeadTime.hour1 => const Duration(hours: 1),
      };

  static NotificationLeadTime fromStorage(String? value) {
    return switch (value) {
      'none' => NotificationLeadTime.none,
      'minutes5' => NotificationLeadTime.minutes5,
      'minutes30' => NotificationLeadTime.minutes30,
      'hour1' => NotificationLeadTime.hour1,
      _ => NotificationLeadTime.minutes15,
    };
  }

  String get storageValue => switch (this) {
        NotificationLeadTime.none => 'none',
        NotificationLeadTime.minutes5 => 'minutes5',
        NotificationLeadTime.minutes15 => 'minutes15',
        NotificationLeadTime.minutes30 => 'minutes30',
        NotificationLeadTime.hour1 => 'hour1',
      };
}

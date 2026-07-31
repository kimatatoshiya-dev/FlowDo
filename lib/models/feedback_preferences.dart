/// 効果音・ハプティックのユーザー設定
class FeedbackPreferences {
  const FeedbackPreferences({
    this.soundEnabled = false,
    this.hapticEnabled = true,
  });

  /// 初期値（効果音 OFF / ハプティック ON）
  static const defaults = FeedbackPreferences();

  final bool soundEnabled;
  final bool hapticEnabled;

  FeedbackPreferences copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
  }) {
    return FeedbackPreferences(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedbackPreferences &&
        other.soundEnabled == soundEnabled &&
        other.hapticEnabled == hapticEnabled;
  }

  @override
  int get hashCode => Object.hash(soundEnabled, hapticEnabled);

  Map<String, dynamic> toJson() => {
        'soundEnabled': soundEnabled,
        'hapticEnabled': hapticEnabled,
      };

  factory FeedbackPreferences.fromJson(Map<String, dynamic> json) {
    return FeedbackPreferences(
      soundEnabled: json['soundEnabled'] == true,
      hapticEnabled: json['hapticEnabled'] != false,
    );
  }
}

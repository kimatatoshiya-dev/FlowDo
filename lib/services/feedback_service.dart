import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/feedback_preferences.dart';

/// 効果音・ハプティックを鳴らすタイミング
enum FeedbackEvent {
  /// タスク登録（Light Impact / 控えめな「コッ」）
  taskRegistered,

  /// タスク完了（Medium Impact / 「ポロン♪」）
  taskCompleted,

  /// AI 整理（Light Impact / 「シャーー…」のみ・完了音なし）
  taskOrganizeStarted,
}

/// 効果音アセット（assets/sounds/ 配下）
abstract final class FeedbackSounds {
  static const taskRegistered = 'sounds/task_registered.wav';
  static const taskCompleted = 'sounds/task_completed.wav';
  static const taskOrganizeFlow = 'sounds/task_organize_flow.wav';

  static String? assetFor(FeedbackEvent event) {
    return switch (event) {
      FeedbackEvent.taskRegistered => taskRegistered,
      FeedbackEvent.taskCompleted => taskCompleted,
      FeedbackEvent.taskOrganizeStarted => taskOrganizeFlow,
    };
  }

  /// イベントごとの再生音量（控えめ・上質なバランス）
  static double volumeFor(FeedbackEvent event) {
    return switch (event) {
      FeedbackEvent.taskRegistered => 0.55,
      FeedbackEvent.taskCompleted => 0.68,
      FeedbackEvent.taskOrganizeStarted => 0.48,
    };
  }
}

/// 効果音・ハプティックの再生インターフェース
abstract class FeedbackService {
  FeedbackPreferences get preferences;

  void updatePreferences(FeedbackPreferences preferences);

  /// ユーザー設定を反映してフィードバックを再生する
  Future<void> play(FeedbackEvent event);

  /// AI 整理の静かな演出（開始時のみ Light Impact + 「シャーー…」）
  Future<void> runOrganizeFeedback(Future<void> Function() organize);

  /// リソース解放（アプリ終了時など）
  Future<void> dispose();
}

/// Flutter 標準 API + audioplayers による実装（iOS / Android）
class NativeFeedbackService implements FeedbackService {
  NativeFeedbackService([FeedbackPreferences? preferences])
      : _preferences = preferences ?? FeedbackPreferences.defaults;

  FeedbackPreferences _preferences;
  AudioPlayer? _soundPlayer;

  Future<AudioPlayer> _ensureSoundPlayer() async {
    final existing = _soundPlayer;
    if (existing != null) return existing;

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    _soundPlayer = player;
    return player;
  }

  @override
  FeedbackPreferences get preferences => _preferences;

  @override
  void updatePreferences(FeedbackPreferences preferences) {
    _preferences = preferences;
  }

  @override
  Future<void> play(FeedbackEvent event) async {
    if (_preferences.hapticEnabled) {
      unawaited(_playHaptic(event));
    }
    if (_preferences.soundEnabled) {
      await _playSound(event);
    }
  }

  @override
  Future<void> runOrganizeFeedback(Future<void> Function() organize) async {
    if (_preferences.hapticEnabled) {
      unawaited(_playHaptic(FeedbackEvent.taskOrganizeStarted));
    }
    if (_preferences.soundEnabled) {
      unawaited(_playSound(FeedbackEvent.taskOrganizeStarted));
    }

    await organize();
  }

  Future<void> _playHaptic(FeedbackEvent event) async {
    switch (event) {
      case FeedbackEvent.taskRegistered:
      case FeedbackEvent.taskOrganizeStarted:
        await HapticFeedback.lightImpact();
      case FeedbackEvent.taskCompleted:
        await HapticFeedback.mediumImpact();
    }
  }

  Future<void> _playSound(FeedbackEvent event) async {
    final asset = FeedbackSounds.assetFor(event);
    if (asset == null) return;

    await _playAsset(asset, FeedbackSounds.volumeFor(event));
  }

  Future<void> _playAsset(String asset, double volume) async {
    try {
      final player = await _ensureSoundPlayer();
      await player.stop();
      await player.play(
        AssetSource(asset),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (error, stack) {
      debugPrint('Failed to play feedback sound: $error');
      debugPrint(stack.toString());
    }
  }

  @override
  Future<void> dispose() async {
    await _soundPlayer?.dispose();
    _soundPlayer = null;
  }
}

/// テスト用 no-op 実装
class NoOpFeedbackService implements FeedbackService {
  NoOpFeedbackService([FeedbackPreferences? preferences])
      : _preferences = preferences ?? FeedbackPreferences.defaults;

  FeedbackPreferences _preferences;

  @override
  FeedbackPreferences get preferences => _preferences;

  @override
  void updatePreferences(FeedbackPreferences preferences) {
    _preferences = preferences;
  }

  @override
  Future<void> play(FeedbackEvent event) async {}

  @override
  Future<void> runOrganizeFeedback(Future<void> Function() organize) async {
    await organize();
  }

  @override
  Future<void> dispose() async {}
}

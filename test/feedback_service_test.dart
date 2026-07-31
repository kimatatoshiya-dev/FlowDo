import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/feedback_preferences.dart';
import 'package:flowdo/services/app_storage.dart';
import 'package:flowdo/services/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  group('FeedbackPreferences', () {
    test('初期値は効果音 OFF / ハプティック ON', () {
      const preferences = FeedbackPreferences.defaults;

      expect(preferences.soundEnabled, isFalse);
      expect(preferences.hapticEnabled, isTrue);
    });

    test('JSON 変換で値を保持する', () {
      const preferences = FeedbackPreferences(
        soundEnabled: true,
        hapticEnabled: false,
      );

      final restored = FeedbackPreferences.fromJson(preferences.toJson());

      expect(restored, preferences);
    });
  });

  group('FeedbackSounds', () {
    test('イベントごとにアセットパスを返す', () {
      expect(
        FeedbackSounds.assetFor(FeedbackEvent.taskRegistered),
        'sounds/task_registered.wav',
      );
      expect(
        FeedbackSounds.assetFor(FeedbackEvent.taskCompleted),
        'sounds/task_completed.wav',
      );
      expect(
        FeedbackSounds.assetFor(FeedbackEvent.taskOrganizeStarted),
        'sounds/task_organize_flow.wav',
      );
    });
  });

  group('NativeFeedbackService', () {
    test('効果音 ON でも play は例外を投げない', () async {
      final service = NativeFeedbackService(
        const FeedbackPreferences(soundEnabled: true),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.play(FeedbackEvent.taskRegistered),
        completes,
      );
      await expectLater(
        service.play(FeedbackEvent.taskCompleted),
        completes,
      );
      await expectLater(
        service.play(FeedbackEvent.taskOrganizeStarted),
        completes,
      );
    });

    test('ハプティック ON でも play は例外を投げない', () async {
      final service = NativeFeedbackService();
      addTearDown(service.dispose);

      await expectLater(
        service.play(FeedbackEvent.taskRegistered),
        completes,
      );
      await expectLater(
        service.play(FeedbackEvent.taskCompleted),
        completes,
      );
    });

    test('ハプティック OFF のとき play は例外を投げない', () async {
      final service = NativeFeedbackService(
        const FeedbackPreferences(hapticEnabled: false),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.play(FeedbackEvent.taskRegistered),
        completes,
      );
    });

    test('設定を更新できる', () {
      final service = NativeFeedbackService();
      addTearDown(service.dispose);
      const updated = FeedbackPreferences(hapticEnabled: false);

      service.updatePreferences(updated);

      expect(service.preferences, updated);
    });

    test('runOrganizeFeedback は整理処理後も例外を投げない', () async {
      final service = NativeFeedbackService(
        const FeedbackPreferences(soundEnabled: true),
      );
      addTearDown(service.dispose);
      var organized = false;

      await expectLater(
        service.runOrganizeFeedback(() async {
          organized = true;
        }),
        completes,
      );

      expect(organized, isTrue);
    });
  });

  group('NoOpFeedbackService', () {
    test('play は例外を投げない', () async {
      final service = NoOpFeedbackService();

      await expectLater(
        service.play(FeedbackEvent.taskRegistered),
        completes,
      );
      await expectLater(
        service.play(FeedbackEvent.taskCompleted),
        completes,
      );
    });

    test('設定を更新できる', () {
      final service = NoOpFeedbackService();
      const updated = FeedbackPreferences(soundEnabled: true);

      service.updatePreferences(updated);

      expect(service.preferences, updated);
    });
  });

  group('AppStorage feedback preferences', () {
    test('未保存時は初期値を返す', () async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.warmUp();

      final preferences = await AppStorage.loadFeedbackPreferences();

      expect(preferences, FeedbackPreferences.defaults);
    });

    test('保存と読み込み', () async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.warmUp();

      const preferences = FeedbackPreferences(
        soundEnabled: true,
        hapticEnabled: false,
      );
      await AppStorage.saveFeedbackPreferences(preferences);

      expect(await AppStorage.loadFeedbackPreferences(), preferences);
    });
  });
}

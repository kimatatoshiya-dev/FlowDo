import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/services/app_storage.dart';

void main() {
  tearDown(SharedPreferences.resetStatic);

  group('resolveRegistrationCategoryId', () {
    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(
        id: CategoryItem.defaultRegistrationCategoryId,
        name: '仕事',
        colorValue: 0xFF007AFF,
      ),
      CategoryItem(id: 'personal', name: 'プライベート', colorValue: 0xFF34C759),
    ];

    test('初回は仕事を返す', () {
      expect(
        resolveRegistrationCategoryId(categories: categories),
        CategoryItem.defaultRegistrationCategoryId,
      );
    });

    test('最後に使用したカテゴリーを返す', () {
      expect(
        resolveRegistrationCategoryId(
          lastUsedId: 'personal',
          categories: categories,
        ),
        'personal',
      );
    });

    test('未分類は初期値に使わず仕事へフォールバック', () {
      expect(
        resolveRegistrationCategoryId(
          lastUsedId: CategoryItem.uncategorizedId,
          categories: categories,
        ),
        CategoryItem.defaultRegistrationCategoryId,
      );
    });

    test('存在しない ID は無視して仕事へフォールバック', () {
      expect(
        resolveRegistrationCategoryId(
          lastUsedId: 'deleted',
          categories: categories,
        ),
        CategoryItem.defaultRegistrationCategoryId,
      );
    });
  });

  group('CategoryItem.ensureRegistrationDefaults', () {
    test('未分類のみの既存データに仕事を補完する', () {
      const legacy = [
        CategoryItem(
          id: CategoryItem.uncategorizedId,
          name: '未分類',
          colorValue: 0xFF8E8E93,
          isSystem: true,
        ),
      ];

      final merged = CategoryItem.ensureRegistrationDefaults(legacy);

      expect(merged, hasLength(2));
      expect(merged[1].id, CategoryItem.defaultRegistrationCategoryId);
    });
  });

  group('CategoryItem.filterBarCategories', () {
    test('未分類を除外する', () {
      const categories = [
        CategoryItem(
          id: CategoryItem.uncategorizedId,
          name: '未分類',
          colorValue: 0xFF8E8E93,
          isSystem: true,
        ),
        CategoryItem(
          id: CategoryItem.defaultRegistrationCategoryId,
          name: '仕事',
          colorValue: 0xFF007AFF,
        ),
        CategoryItem(id: 'personal', name: 'プライベート', colorValue: 0xFF34C759),
      ];

      final filtered = CategoryItem.filterBarCategories(categories);

      expect(filtered, hasLength(2));
      expect(filtered.map((c) => c.id), ['work', 'personal']);
    });
  });

  group('AppStorage last registration category', () {
    test('保存と読み込み', () async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.warmUp();

      expect(await AppStorage.loadLastRegistrationCategoryId(), isNull);

      await AppStorage.saveLastRegistrationCategoryId('personal');
      expect(await AppStorage.loadLastRegistrationCategoryId(), 'personal');
    });
  });
}

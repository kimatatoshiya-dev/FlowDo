import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';

void main() {
  List<CategoryItem> sampleCategories() => const [
        CategoryItem(
          id: CategoryItem.uncategorizedId,
          name: '未分類',
          colorValue: 0xFF8E8E93,
          isSystem: true,
          displayOrder: 0,
        ),
        CategoryItem(
          id: 'work',
          name: '仕事',
          colorValue: 0xFF007AFF,
          displayOrder: 1,
        ),
        CategoryItem(
          id: 'personal',
          name: 'プライベート',
          colorValue: 0xFF34C759,
          displayOrder: 2,
        ),
        CategoryItem(
          id: 'shopping',
          name: '買い物',
          colorValue: 0xFFFF9500,
          displayOrder: 3,
        ),
        CategoryItem(
          id: 'running',
          name: 'ランニング',
          colorValue: 0xFF5856D6,
          displayOrder: 4,
        ),
      ];

  group('nextCategoryId', () {
    test('未分類から1クリックで次のカテゴリーへ', () {
      final categories = sampleCategories();

      final next = nextCategoryId(
        CategoryItem.uncategorizedId,
        categories,
      );

      expect(next, 'work');
    });

    test('登録順で循環し、最後の次は未分類', () {
      final categories = sampleCategories();

      expect(
        nextCategoryId(CategoryItem.uncategorizedId, categories),
        'work',
      );
      expect(nextCategoryId('work', categories), 'personal');
      expect(nextCategoryId('personal', categories), 'shopping');
      expect(nextCategoryId('shopping', categories), 'running');
      expect(
        nextCategoryId('running', categories),
        CategoryItem.uncategorizedId,
      );
    });

    test('リストに無い ID も未分類と同様に1クリックで次へ', () {
      final categories = sampleCategories();

      final next = nextCategoryId('legacy_work', categories);

      expect(next, 'work');
    });
  });
}

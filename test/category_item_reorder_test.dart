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
      ];

  test('filterBarCategories は displayOrder 順で返す', () {
    final categories = [
      ...sampleCategories(),
      const CategoryItem(
        id: 'running',
        name: 'ランニング',
        colorValue: 0xFF5856D6,
        displayOrder: 4,
      ),
    ].reversed.toList();

    expect(
      CategoryItem.filterBarCategories(categories)
          .map((category) => category.id)
          .toList(),
      ['work', 'personal', 'shopping', 'running'],
    );
  });

  test('applyBarOrder は並び替え結果を displayOrder へ反映する', () {
    final categories = sampleCategories();
    final reordered = CategoryItem.applyBarOrder(categories, [
      categories[3],
      categories[1],
      categories[2],
    ]);

    expect(
      CategoryItem.filterBarCategories(reordered)
          .map((category) => category.id)
          .toList(),
      ['shopping', 'work', 'personal'],
    );
  });

  test('reorderFilterBarCategories は index を正規化して並べ替える', () {
    final reordered = reorderFilterBarCategories(sampleCategories(), 0, 2);

    expect(reordered.map((category) => category.id).toList(), [
      'personal',
      'work',
      'shopping',
    ]);
  });

  test('nextDisplayOrder は最大値 + 1 を返す', () {
    expect(CategoryItem.nextDisplayOrder(sampleCategories()), 4);
  });
}

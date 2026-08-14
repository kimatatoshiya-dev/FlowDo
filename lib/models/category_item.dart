import 'package:flutter/material.dart';

import '../utils/json_read.dart';

/// ユーザー管理可能なカテゴリー
class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isSystem = false,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool isSystem;

  /// グループ一覧の表示順（小さいほど先頭）
  final int displayOrder;

  Color get color => Color(colorValue);

  /// 未分類カテゴリーの ID
  static const uncategorizedId = 'uncategorized';

  /// 新規登録時の初回デフォルトカテゴリー ID
  static const defaultRegistrationCategoryId = 'work';

  /// 初回起動時のカテゴリー（未分類 + 仕事）
  static List<CategoryItem> defaults() => const [
        CategoryItem(
          id: uncategorizedId,
          name: '未分類',
          colorValue: 0xFF8E8E93,
          isSystem: true,
          displayOrder: 0,
        ),
        CategoryItem(
          id: defaultRegistrationCategoryId,
          name: '仕事',
          colorValue: 0xFF007AFF,
          displayOrder: 1,
        ),
      ];

  /// 未分類のみ保存されている既存データに仕事カテゴリーを補完する
  static List<CategoryItem> ensureRegistrationDefaults(
    List<CategoryItem> loaded,
  ) {
    if (loaded.isEmpty) return defaults();

    final hasNonUncategorized =
        loaded.any((c) => c.id != uncategorizedId);
    if (hasNonUncategorized) return loaded;

    return normalizeDisplayOrder([
      ...loaded,
      ...defaults().where((c) => c.id != uncategorizedId),
    ]);
  }

  /// 保存データに displayOrder が無い場合は配列順で補完する
  static List<CategoryItem> normalizeDisplayOrder(List<CategoryItem> categories) {
    if (categories.isEmpty) return categories;

    final hasLegacyOrder = categories.any((category) => category.displayOrder < 0);
    if (hasLegacyOrder) {
      return [
        for (var i = 0; i < categories.length; i++)
          categories[i].copyWith(displayOrder: i),
      ];
    }

    return sortedByDisplayOrder(categories);
  }

  static List<CategoryItem> sortedByDisplayOrder(List<CategoryItem> categories) {
    final indexed = categories.asMap().entries.toList()
      ..sort((a, b) {
        final orderCompare =
            a.value.displayOrder.compareTo(b.value.displayOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  /// ホーム画面のカテゴリーフィルターに表示するカテゴリー（未分類は除外）
  static List<CategoryItem> filterBarCategories(List<CategoryItem> categories) {
    return sortedByDisplayOrder(categories)
        .where((category) => category.id != uncategorizedId)
        .toList(growable: false);
  }

  /// 横並びグループの並び替え結果を全体リストへ反映する
  static List<CategoryItem> applyBarOrder(
    List<CategoryItem> allCategories,
    List<CategoryItem> reorderedBarCategories,
  ) {
    final byId = {for (final category in allCategories) category.id: category};
    final updated = <String, CategoryItem>{};

    for (final category in allCategories) {
      if (category.id == uncategorizedId) {
        updated[category.id] = category.copyWith(displayOrder: 0);
      }
    }

    var order = 1;
    for (final category in reorderedBarCategories) {
      final current = byId[category.id];
      if (current == null) continue;
      updated[current.id] = current.copyWith(displayOrder: order++);
    }

    for (final category in allCategories) {
      updated.putIfAbsent(category.id, () => category);
    }

    return normalizeDisplayOrder(updated.values.toList(growable: false));
  }

  static int nextDisplayOrder(List<CategoryItem> categories) {
    if (categories.isEmpty) return 1;
    return categories
            .map((category) => category.displayOrder)
            .fold(0, (max, value) => value > max ? value : max) +
        1;
  }

  /// ユーザー追加カテゴリーを生成する
  factory CategoryItem.create({
    required String name,
    required int colorValue,
    int displayOrder = 0,
  }) {
    return CategoryItem(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colorValue: colorValue,
      displayOrder: displayOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'isSystem': isSystem,
        'displayOrder': displayOrder,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final id = JsonRead.string(json['id']);
    final name = JsonRead.string(json['name']);
    final colorValue = JsonRead.integer(json['colorValue']);
    if (id == null || name == null || colorValue == null) {
      throw FormatException('Category requires id, name, colorValue: $json');
    }

    return CategoryItem(
      id: id,
      name: name,
      colorValue: colorValue,
      isSystem: json['isSystem'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? -1,
    );
  }

  CategoryItem copyWith({
    String? name,
    int? colorValue,
    int? displayOrder,
  }) {
    return CategoryItem(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isSystem: isSystem,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}

/// 新規登録時に使うカテゴリー ID を決める（未分類は初期値に使わない）
String resolveRegistrationCategoryId({
  String? lastUsedId,
  required List<CategoryItem> categories,
}) {
  if (lastUsedId != null &&
      lastUsedId != CategoryItem.uncategorizedId &&
      categories.any((c) => c.id == lastUsedId)) {
    return lastUsedId;
  }

  if (categories.any(
    (c) => c.id == CategoryItem.defaultRegistrationCategoryId,
  )) {
    return CategoryItem.defaultRegistrationCategoryId;
  }

  for (final category in CategoryItem.filterBarCategories(categories)) {
    return category.id;
  }

  return CategoryItem.defaultRegistrationCategoryId;
}

/// ID からカテゴリーを検索する（見つからなければ未分類）
CategoryItem resolveCategory(String categoryId, List<CategoryItem> categories) {
  return categories.firstWhere(
    (c) => c.id == categoryId,
    orElse: () => CategoryItem.defaults().first,
  );
}

/// タップで次のカテゴリー ID を返す（表示順で循環）
String nextCategoryId(String currentId, List<CategoryItem> categories) {
  final ordered = CategoryItem.sortedByDisplayOrder(categories);
  if (ordered.isEmpty) return CategoryItem.uncategorizedId;
  if (ordered.length == 1) return ordered.first.id;

  final currentIndex = ordered.indexWhere((c) => c.id == currentId);
  if (currentIndex >= 0) {
    return ordered[(currentIndex + 1) % ordered.length].id;
  }

  // リストに無い ID は未分類と同じ位置から次のカテゴリーへ
  final uncategorizedIndex = ordered.indexWhere(
    (c) => c.id == CategoryItem.uncategorizedId,
  );
  if (uncategorizedIndex >= 0) {
    return ordered[(uncategorizedIndex + 1) % ordered.length].id;
  }

  return ordered.first.id;
}

/// 新規カテゴリー用の色候補
const categoryColorPalette = [
  0xFF007AFF,
  0xFFAF52DE,
  0xFF34C759,
  0xFFFF9500,
  0xFFFF3B30,
  0xFF5856D6,
  0xFF00C7BE,
];

/// 横並び ReorderableListView 用の index 補正
int normalizeReorderableDropIndex(int oldIndex, int newIndex) {
  if (newIndex > oldIndex) newIndex -= 1;
  return newIndex;
}

/// 並び替え後の filter bar 用リストを生成する
List<CategoryItem> reorderFilterBarCategories(
  List<CategoryItem> categories,
  int oldIndex,
  int newIndex,
) {
  final barCategories = CategoryItem.filterBarCategories(categories);
  if (oldIndex < 0 ||
      oldIndex >= barCategories.length ||
      newIndex < 0 ||
      newIndex > barCategories.length) {
    return barCategories;
  }

  final normalizedIndex = normalizeReorderableDropIndex(oldIndex, newIndex);
  final updated = [...barCategories];
  final moved = updated.removeAt(oldIndex);
  updated.insert(normalizedIndex, moved);
  return updated;
}

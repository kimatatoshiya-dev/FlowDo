import 'package:flutter/material.dart';

import '../utils/json_read.dart';

/// ユーザー管理可能なカテゴリー
class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool isSystem;

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
        ),
        CategoryItem(
          id: defaultRegistrationCategoryId,
          name: '仕事',
          colorValue: 0xFF007AFF,
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

    return [
      ...loaded,
      ...defaults().where((c) => c.id != uncategorizedId),
    ];
  }

  /// ホーム画面のカテゴリーフィルターに表示するカテゴリー（未分類は除外）
  static List<CategoryItem> filterBarCategories(List<CategoryItem> categories) {
    return categories
        .where((category) => category.id != uncategorizedId)
        .toList(growable: false);
  }

  /// ユーザー追加カテゴリーを生成する
  factory CategoryItem.create({required String name, required int colorValue}) {
    return CategoryItem(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colorValue: colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'isSystem': isSystem,
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
      isSystem: JsonRead.boolean(json['isSystem']),
    );
  }

  CategoryItem copyWith({String? name, int? colorValue}) {
    return CategoryItem(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isSystem: isSystem,
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

  for (final category in categories) {
    if (category.id != CategoryItem.uncategorizedId) {
      return category.id;
    }
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

/// タップで次のカテゴリー ID を返す（登録順で循環）
String nextCategoryId(String currentId, List<CategoryItem> categories) {
  if (categories.isEmpty) return CategoryItem.uncategorizedId;
  if (categories.length == 1) return categories.first.id;

  final currentIndex = categories.indexWhere((c) => c.id == currentId);
  if (currentIndex >= 0) {
    return categories[(currentIndex + 1) % categories.length].id;
  }

  // リストに無い ID は未分類と同じ位置から次のカテゴリーへ
  final uncategorizedIndex = categories.indexWhere(
    (c) => c.id == CategoryItem.uncategorizedId,
  );
  if (uncategorizedIndex >= 0) {
    return categories[(uncategorizedIndex + 1) % categories.length].id;
  }

  return categories.first.id;
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

import '../models/category_item.dart';

/// AI が提案するカテゴリー候補
class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryId,
    this.confidence = 1.0,
    this.reason,
  });

  final String categoryId;
  final double confidence;
  final String? reason;
}

/// AI によるタスク分類サービス（OpenAI API 差し替え可能）
abstract class AiCategorizerService {
  /// タスク名から最適なカテゴリー ID を推測する
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  });

  /// タスク内容からカテゴリー候補を複数提案する（将来の UI 用）
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  });
}

/// ダミー実装
class DummyAiCategorizerService implements AiCategorizerService {
  const DummyAiCategorizerService();

  @override
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    final suggestions = await suggestCategories(
      title: title,
      categories: categories,
    );
    return suggestions.isEmpty
        ? CategoryItem.uncategorizedId
        : suggestions.first.categoryId;
  }

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    // 将来: OpenAI API でタスク内容を解析し候補を返す
    return const [
      CategorySuggestion(
        categoryId: CategoryItem.uncategorizedId,
        confidence: 0.0,
        reason: 'AI 未接続',
      ),
    ];
  }
}

/// 将来の OpenAI API 接続用（未実装）
class OpenAiCategorizerService implements AiCategorizerService {
  OpenAiCategorizerService({required this.apiKey});

  final String apiKey;

  @override
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    final suggestions = await suggestCategories(
      title: title,
      categories: categories,
    );
    if (suggestions.isEmpty) return CategoryItem.uncategorizedId;
    return suggestions.first.categoryId;
  }

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    throw UnimplementedError('OpenAI API は未接続です');
  }
}

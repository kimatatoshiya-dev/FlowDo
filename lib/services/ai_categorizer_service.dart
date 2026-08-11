import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/category_item.dart';
import '../utils/json_read.dart';

/// バッチ分類結果（1タスク分）
class TaskCategorizationResult {
  const TaskCategorizationResult({
    required this.title,
    required this.categoryId,
    this.priorityStars = 0,
    this.reason,
  });

  final String title;
  final String categoryId;
  final int priorityStars;
  final String? reason;
}

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

  /// 未分類タスクを1リクエストで一括分類する
  Future<List<TaskCategorizationResult>> categorizeBatch({
    required List<String> titles,
    required List<CategoryItem> categories,
  });

  /// タスク内容からカテゴリー候補を複数提案する（将来の UI 用）
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  });
}

/// `.env` の OPENAI_API_KEY があれば OpenAI、なければダミーにフォールバック
AiCategorizerService createAiCategorizerService() {
  String? apiKey;
  try {
    apiKey = dotenv.env['OPENAI_API_KEY']?.trim();
  } catch (error) {
    debugPrint('dotenv unavailable; using DummyAiCategorizerService ($error)');
  }

  if (apiKey != null && apiKey.isNotEmpty) {
    return OpenAiCategorizerService(apiKey: apiKey);
  }
  debugPrint('OPENAI_API_KEY not set; using DummyAiCategorizerService');
  return const DummyAiCategorizerService();
}

/// ダミー実装（API キー未設定時のフォールバック）
class DummyAiCategorizerService implements AiCategorizerService {
  const DummyAiCategorizerService();

  @override
  Future<List<TaskCategorizationResult>> categorizeBatch({
    required List<String> titles,
    required List<CategoryItem> categories,
  }) async {
    return titles
        .map(
          (title) => TaskCategorizationResult(
            title: title,
            categoryId: CategoryItem.uncategorizedId,
            reason: 'AI 未接続',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    final results = await categorizeBatch(
      titles: [title],
      categories: categories,
    );
    return results.isEmpty
        ? CategoryItem.uncategorizedId
        : results.first.categoryId;
  }

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    return const [
      CategorySuggestion(
        categoryId: CategoryItem.uncategorizedId,
        confidence: 0.0,
        reason: 'AI 未接続',
      ),
    ];
  }
}

/// OpenAI Responses API によるタスク一括分類
class OpenAiCategorizerService implements AiCategorizerService {
  OpenAiCategorizerService({
    required this.apiKey,
    http.Client? httpClient,
    this.model = 'gpt-4o-mini',
    this.requestTimeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client();

  static const _endpoint = 'https://api.openai.com/v1/responses';

  final String apiKey;
  final String model;
  final Duration requestTimeout;
  final http.Client _httpClient;

  @override
  Future<List<TaskCategorizationResult>> categorizeBatch({
    required List<String> titles,
    required List<CategoryItem> categories,
  }) async {
    final trimmedTitles = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);

    if (trimmedTitles.isEmpty) return const [];

    final assignableCategories = categories
        .where((category) => category.id != CategoryItem.uncategorizedId)
        .toList(growable: false);

    if (assignableCategories.isEmpty) {
      return trimmedTitles
          .map(
            (title) => TaskCategorizationResult(
              title: title,
              categoryId: CategoryItem.uncategorizedId,
              reason: '分類先カテゴリーがありません',
            ),
          )
          .toList(growable: false);
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              _buildBatchRequestBody(
                titles: trimmedTitles,
                categories: assignableCategories,
              ),
            ),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          'OpenAI batch categorize failed: HTTP ${response.statusCode} ${response.body}',
        );
        return _fallbackBatch(
          trimmedTitles,
          'OpenAI API エラー (${response.statusCode})',
        );
      }

      return _parseBatchResponse(
        responseBody: response.body,
        categories: assignableCategories,
        expectedTitles: trimmedTitles,
      );
    } catch (error, stack) {
      debugPrint('OpenAI batch categorize error: $error');
      debugPrint(stack.toString());
      return _fallbackBatch(trimmedTitles, 'OpenAI API 呼び出し失敗');
    }
  }

  @override
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    final results = await categorizeBatch(
      titles: [title],
      categories: categories,
    );
    if (results.isEmpty) return CategoryItem.uncategorizedId;
    return results.first.categoryId;
  }

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  }) async {
    final results = await categorizeBatch(
      titles: [title],
      categories: categories,
    );
    if (results.isEmpty) {
      return _fallbackSuggestion('空のタスク');
    }

    final result = results.first;
    return [
      CategorySuggestion(
        categoryId: result.categoryId,
        confidence:
            result.categoryId == CategoryItem.uncategorizedId ? 0.0 : 1.0,
        reason: result.reason,
      ),
    ];
  }

  Map<String, dynamic> _buildBatchRequestBody({
    required List<String> titles,
    required List<CategoryItem> categories,
  }) {
    final categoryList = categories
        .map((category) => {'id': category.id, 'name': category.name})
        .toList(growable: false);

    return {
      'model': model,
      'store': false,
      'instructions':
          'あなたはタスク管理アプリの分類アシスタントです。'
          '入力されたすべてのタスクを、候補カテゴリー名と優先度に分類してください。'
          'category には候補カテゴリーの name をそのまま使ってください。'
          'priority は "none", "1", "2", "3", "4", "5" のいずれかにしてください。'
          '入力タスクごとに1件ずつ、tasks 配列に結果を返してください。',
      'input': jsonEncode({
        'tasks': titles,
        'categories': categoryList,
      }),
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'task_categorizations',
          'strict': true,
          'schema': {
            'type': 'object',
            'properties': {
              'tasks': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {'type': 'string'},
                    'category': {'type': 'string'},
                    'priority': {'type': 'string'},
                    'reason': {'type': 'string'},
                  },
                  'required': ['title', 'category', 'priority', 'reason'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['tasks'],
            'additionalProperties': false,
          },
        },
      },
    };
  }

  List<TaskCategorizationResult> _parseBatchResponse({
    required String responseBody,
    required List<CategoryItem> categories,
    required List<String> expectedTitles,
  }) {
    try {
      final outputText = _extractOutputText(responseBody);
      if (outputText == null) {
        return _fallbackBatch(expectedTitles, 'OpenAI 応答の解析に失敗');
      }

      final payload = jsonDecode(outputText);
      if (payload is! Map<String, dynamic>) {
        return _fallbackBatch(expectedTitles, 'OpenAI 応答の形式が不正');
      }

      final tasksRaw = payload['tasks'];
      if (tasksRaw is! List) {
        return _fallbackBatch(expectedTitles, 'OpenAI 応答の形式が不正');
      }

      final byTitle = <String, TaskCategorizationResult>{};
      for (final item in tasksRaw) {
        if (item is! Map) continue;

        final title = JsonRead.string(item['title'])?.trim();
        if (title == null || title.isEmpty) continue;

        final categoryName = JsonRead.string(item['category']) ?? '';
        byTitle[title] = TaskCategorizationResult(
          title: title,
          categoryId: _resolveCategoryId(categoryName, categories),
          priorityStars: _parsePriority(item['priority']),
          reason: JsonRead.string(item['reason']),
        );
      }

      return [
        for (final title in expectedTitles)
          byTitle[title] ??
              TaskCategorizationResult(
                title: title,
                categoryId: CategoryItem.uncategorizedId,
                reason: '分類結果が見つかりません',
              ),
      ];
    } catch (error, stack) {
      debugPrint('Failed to parse OpenAI response: $error');
      debugPrint(stack.toString());
      return _fallbackBatch(expectedTitles, 'OpenAI 応答の解析に失敗');
    }
  }

  String? _extractOutputText(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;

    final topLevel = JsonRead.string(decoded['output_text']);
    if (topLevel != null && topLevel.isNotEmpty) return topLevel;

    final output = decoded['output'];
    if (output is! List) return null;

    for (final item in output) {
      if (item is! Map || item['type'] != 'message') continue;

      final content = item['content'];
      if (content is! List) continue;

      for (final part in content) {
        if (part is Map && part['type'] == 'output_text') {
          final text = JsonRead.string(part['text']);
          if (text != null && text.isNotEmpty) return text;
        }
      }
    }

    return null;
  }

  String _resolveCategoryId(String value, List<CategoryItem> categories) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return CategoryItem.uncategorizedId;

    for (final category in categories) {
      if (category.id == trimmed || category.name == trimmed) {
        return category.id;
      }
    }

    return CategoryItem.uncategorizedId;
  }

  int _parsePriority(dynamic value) {
    final raw = JsonRead.string(value) ?? value?.toString() ?? '';
    if (raw == 'none' || raw.isEmpty) return 0;
    return int.tryParse(raw)?.clamp(0, 5) ?? 0;
  }

  List<TaskCategorizationResult> _fallbackBatch(
    List<String> titles,
    String reason,
  ) {
    return titles
        .map(
          (title) => TaskCategorizationResult(
            title: title,
            categoryId: CategoryItem.uncategorizedId,
            reason: reason,
          ),
        )
        .toList(growable: false);
  }

  List<CategorySuggestion> _fallbackSuggestion(String reason) {
    return [
      CategorySuggestion(
        categoryId: CategoryItem.uncategorizedId,
        confidence: 0.0,
        reason: reason,
      ),
    ];
  }
}

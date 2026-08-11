import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/services/ai_categorizer_service.dart';

void main() {
  const categories = [
    CategoryItem(
      id: CategoryItem.uncategorizedId,
      name: '未分類',
      colorValue: 0xFF8E8E93,
      isSystem: true,
    ),
    CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
    CategoryItem(id: 'personal', name: 'プライベート', colorValue: 0xFF34C759),
  ];

  group('OpenAiCategorizerService', () {
    test('複数タスクを1リクエストで分類する', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/responses');
        expect(request.headers['Authorization'], 'Bearer test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o-mini');
        expect(body['store'], false);
        expect(body['text'], isA<Map<String, dynamic>>());

        final input =
            jsonDecode(body['input'] as String) as Map<String, dynamic>;
        expect(input['tasks'], ['資料作成', '買い物']);

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {
                      'type': 'output_text',
                      'text': jsonEncode({
                        'tasks': [
                          {
                            'title': '資料作成',
                            'category': '仕事',
                            'priority': '4',
                            'reason': 'work related',
                          },
                          {
                            'title': '買い物',
                            'category': 'プライベート',
                            'priority': '2',
                            'reason': 'personal errand',
                          },
                        ],
                      }),
                    },
                  ],
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiCategorizerService(
        apiKey: 'test-key',
        httpClient: client,
      );

      final results = await service.categorizeBatch(
        titles: ['資料作成', '買い物'],
        categories: categories,
      );

      expect(results, hasLength(2));
      expect(results[0].categoryId, 'work');
      expect(results[0].priorityStars, 4);
      expect(results[1].categoryId, 'personal');
    });

    test('未知の category は未分類にフォールバックする', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {
                      'type': 'output_text',
                      'text': jsonEncode({
                        'tasks': [
                          {
                            'title': 'shopping',
                            'category': 'unknown',
                            'priority': 'none',
                            'reason': 'unclear',
                          },
                        ],
                      }),
                    },
                  ],
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = OpenAiCategorizerService(
        apiKey: 'test-key',
        httpClient: client,
      );

      final results = await service.categorizeBatch(
        titles: ['shopping'],
        categories: categories,
      );

      expect(results.first.categoryId, CategoryItem.uncategorizedId);
    });

    test('API エラー時は未分類にフォールバックする', () async {
      final client = MockClient((request) async {
        return http.Response('error', 500);
      });

      final service = OpenAiCategorizerService(
        apiKey: 'test-key',
        httpClient: client,
      );

      final results = await service.categorizeBatch(
        titles: ['会議'],
        categories: categories,
      );

      expect(results, hasLength(1));
      expect(results.first.categoryId, CategoryItem.uncategorizedId);
    });
  });
}

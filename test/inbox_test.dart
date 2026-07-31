import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/ai_categorizer_service.dart';
import 'package:flowdo/services/task_organizer_service.dart';

void main() {
  const categories = [
    CategoryItem(
      id: CategoryItem.uncategorizedId,
      name: '未分類',
      colorValue: 0xFF8E8E93,
      isSystem: true,
    ),
    CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
  ];

  group('LocalTaskOrganizerService', () {
    test('手動で設定したカテゴリーを優先する', () async {
      const organizer = LocalTaskOrganizerService();
      final tasks = [
        Task(
          id: 0,
          title: '会議',
          isInbox: true,
          categoryId: 'work',
        ),
      ];

      final plans = await organizer.planOrganization(
        inboxTasks: tasks,
        categories: categories,
      );

      expect(plans, hasLength(1));
      expect(plans.first.categoryId, 'work');
    });

    test('未設定のカテゴリーは分類サービスに委譲する', () async {
      final organizer = LocalTaskOrganizerService(
        categorizer: _FixedCategorizer('work'),
      );
      final tasks = [Task(id: 0, title: '資料作成', isInbox: true)];

      final plans = await organizer.planOrganization(
        inboxTasks: tasks,
        categories: categories,
      );

      expect(plans.first.categoryId, 'work');
    });
  });
}

class _FixedCategorizer implements AiCategorizerService {
  const _FixedCategorizer(this.categoryId);

  final String categoryId;

  @override
  Future<String> categorize({
    required String title,
    required List<CategoryItem> categories,
  }) async =>
      categoryId;

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    required String title,
    required List<CategoryItem> categories,
  }) async =>
      [];
}

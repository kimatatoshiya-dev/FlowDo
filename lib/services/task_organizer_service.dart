import '../models/category_item.dart';
import '../models/task.dart';
import 'ai_categorizer_service.dart';

/// 整理結果（1タスク分）
class TaskOrganizationPlan {
  const TaskOrganizationPlan({
    required this.taskId,
    required this.categoryId,
    this.reason,
  });

  final int taskId;
  final String categoryId;
  final String? reason;
}

/// 最近追加したタスクをカテゴリーへ振り分けるサービス（AI 差し替え可能）
abstract class TaskOrganizerService {
  Future<List<TaskOrganizationPlan>> planOrganization({
    required List<Task> inboxTasks,
    required List<CategoryItem> categories,
  });
}

/// ローカル整理（手動設定カテゴリー優先、未設定は AI / ダミー分類）
class LocalTaskOrganizerService implements TaskOrganizerService {
  const LocalTaskOrganizerService({
    AiCategorizerService? categorizer,
  }) : _categorizer = categorizer ?? const DummyAiCategorizerService();

  final AiCategorizerService _categorizer;

  @override
  Future<List<TaskOrganizationPlan>> planOrganization({
    required List<Task> inboxTasks,
    required List<CategoryItem> categories,
  }) async {
    final plans = <TaskOrganizationPlan>[];

    for (final task in inboxTasks) {
      final categoryId = await _resolveCategoryId(
        task: task,
        categories: categories,
      );
      plans.add(TaskOrganizationPlan(taskId: task.id, categoryId: categoryId));
    }

    return plans;
  }

  Future<String> _resolveCategoryId({
    required Task task,
    required List<CategoryItem> categories,
  }) async {
    final hasManualCategory =
        task.categoryId != CategoryItem.uncategorizedId &&
            categories.any((c) => c.id == task.categoryId);

    if (hasManualCategory) {
      return task.categoryId;
    }

    return _categorizer.categorize(title: task.title, categories: categories);
  }
}

/// 将来の AI 一括整理用（未実装）
class AiTaskOrganizerService implements TaskOrganizerService {
  AiTaskOrganizerService({required this.categorizer});

  final AiCategorizerService categorizer;

  @override
  Future<List<TaskOrganizationPlan>> planOrganization({
    required List<Task> inboxTasks,
    required List<CategoryItem> categories,
  }) {
    throw UnimplementedError('AI 一括整理は未接続です');
  }
}

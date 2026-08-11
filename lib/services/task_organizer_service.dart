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

/// ローカル整理（手動設定カテゴリー優先、未設定は AI 一括分類）
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
    final uncategorizedTasks = <Task>[];

    for (final task in inboxTasks) {
      if (_hasManualCategory(task, categories)) {
        plans.add(
          TaskOrganizationPlan(taskId: task.id, categoryId: task.categoryId),
        );
      } else {
        uncategorizedTasks.add(task);
      }
    }

    if (uncategorizedTasks.isNotEmpty) {
      final batchResults = await _categorizer.categorizeBatch(
        titles: uncategorizedTasks.map((task) => task.title).toList(growable: false),
        categories: categories,
      );

      for (var i = 0; i < uncategorizedTasks.length; i++) {
        final task = uncategorizedTasks[i];
        final result = i < batchResults.length ? batchResults[i] : null;
        plans.add(
          TaskOrganizationPlan(
            taskId: task.id,
            categoryId: result?.categoryId ?? CategoryItem.uncategorizedId,
            reason: result?.reason,
          ),
        );
      }
    }

    return plans;
  }

  bool _hasManualCategory(Task task, List<CategoryItem> categories) {
    return task.categoryId != CategoryItem.uncategorizedId &&
        categories.any((category) => category.id == task.categoryId);
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

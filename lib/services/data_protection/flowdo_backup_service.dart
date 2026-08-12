import 'dart:convert';

import '../../models/category_item.dart';
import '../../models/flowdo_data_snapshot.dart';
import '../../models/task.dart';
import '../tasks/guest_task_migration.dart';

/// インポート時の統合方法
enum FlowDoImportMode {
  /// 既存データとマージ（同一 ID はインポート側を優先）
  merge,

  /// 現在のデータをインポートで置き換え
  replace,
}

/// インポート適用結果
class FlowDoImportResult {
  const FlowDoImportResult({
    required this.tasks,
    required this.categories,
    required this.lastRegistrationCategoryId,
    required this.importedTaskCount,
    required this.importedCategoryCount,
  });

  final List<Task> tasks;
  final List<CategoryItem> categories;
  final String? lastRegistrationCategoryId;
  final int importedTaskCount;
  final int importedCategoryCount;
}

/// JSON エクスポート／インポートのコアロジック
abstract final class FlowDoBackupService {
  static FlowDoDataSnapshot buildSnapshot({
    required List<Task> tasks,
    required List<CategoryItem> categories,
    String? lastRegistrationCategoryId,
    String source = 'local',
    DateTime? exportedAt,
  }) {
    return FlowDoDataSnapshot(
      schemaVersion: FlowDoDataSnapshot.currentSchemaVersion,
      exportedAt: exportedAt ?? DateTime.now(),
      source: source,
      payload: FlowDoDataPayload(
        tasks: List<Task>.from(tasks),
        categories: List<CategoryItem>.from(categories),
        lastRegistrationCategoryId: lastRegistrationCategoryId,
      ),
    );
  }

  static String encodeSnapshot(FlowDoDataSnapshot snapshot) {
    return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
  }

  static FlowDoDataSnapshot decodeSnapshot(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return FlowDoDataSnapshot.fromJson(decoded);
  }

  static String suggestedFileName(DateTime exportedAt) {
    final local = exportedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return 'flowdo-backup-$y$m$d-$h$min.json';
  }

  static FlowDoImportResult applyImport({
    required FlowDoDataSnapshot snapshot,
    required List<Task> currentTasks,
    required List<CategoryItem> currentCategories,
    required String? currentLastRegistrationCategoryId,
    required FlowDoImportMode mode,
  }) {
    final importedTasks = snapshot.payload.tasks;
    final importedCategories = snapshot.payload.categories;

    final tasks = switch (mode) {
      FlowDoImportMode.merge => GuestTaskMigration.mergeTasks(
          localTasks: importedTasks,
          remoteTasks: currentTasks,
        ),
      FlowDoImportMode.replace => () {
          final replaced = List<Task>.from(importedTasks);
          Task.syncNextId(replaced);
          return replaced;
        }(),
    };

    final categories = switch (mode) {
      FlowDoImportMode.merge => _mergeCategories(
          current: currentCategories,
          imported: importedCategories,
        ),
      FlowDoImportMode.replace => CategoryItem.ensureRegistrationDefaults(
          List<CategoryItem>.from(importedCategories),
        ),
    };

    _repairTaskCategoryReferences(tasks, categories);

    final categoryIds = categories.map((category) => category.id).toSet();
    final importedLastCategory = snapshot.payload.lastRegistrationCategoryId;
    final lastRegistrationCategoryId =
        importedLastCategory != null && categoryIds.contains(importedLastCategory)
            ? importedLastCategory
            : currentLastRegistrationCategoryId;

    return FlowDoImportResult(
      tasks: tasks,
      categories: categories,
      lastRegistrationCategoryId: lastRegistrationCategoryId,
      importedTaskCount: importedTasks.length,
      importedCategoryCount: importedCategories.length,
    );
  }

  static List<CategoryItem> _mergeCategories({
    required List<CategoryItem> current,
    required List<CategoryItem> imported,
  }) {
    final mergedById = {for (final category in current) category.id: category};
    for (final category in imported) {
      mergedById[category.id] = category;
    }
    return CategoryItem.ensureRegistrationDefaults(mergedById.values.toList());
  }

  static void _repairTaskCategoryReferences(
    List<Task> tasks,
    List<CategoryItem> categories,
  ) {
    final validIds = categories.map((category) => category.id).toSet();
    for (final task in tasks) {
      if (!validIds.contains(task.categoryId)) {
        task.categoryId = CategoryItem.uncategorizedId;
      }
    }
  }
}

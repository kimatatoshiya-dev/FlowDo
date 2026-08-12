import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/flowdo_data_snapshot.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/data_protection/flowdo_backup_service.dart';

void main() {
  Task createTask({
    required int id,
    required String title,
    String categoryId = CategoryItem.uncategorizedId,
  }) {
    return Task(
      id: id,
      title: title,
      categoryId: categoryId,
      createdAt: DateTime(2026, 1, id),
    );
  }

  group('FlowDoBackupService', () {
    test('エクスポート JSON をデコードして復元できる', () {
      final tasks = [
        createTask(id: 1, title: 'Alpha'),
        createTask(id: 2, title: 'Beta', categoryId: 'work'),
      ];
      final categories = CategoryItem.defaults();
      final exportedAt = DateTime.utc(2026, 8, 12, 1, 30);

      final snapshot = FlowDoBackupService.buildSnapshot(
        tasks: tasks,
        categories: categories,
        lastRegistrationCategoryId: 'work',
        exportedAt: exportedAt,
      );
      final json = FlowDoBackupService.encodeSnapshot(snapshot);
      final decoded = FlowDoBackupService.decodeSnapshot(json);

      expect(decoded.schemaVersion, FlowDoDataSnapshot.currentSchemaVersion);
      expect(decoded.source, 'local');
      expect(decoded.payload.tasks.length, 2);
      expect(decoded.payload.tasks.first.title, 'Alpha');
      expect(decoded.payload.categories.length, categories.length);
      expect(decoded.payload.lastRegistrationCategoryId, 'work');
    });

    test('マージインポートは同一 ID のインポート側を優先する', () {
      final currentTasks = [
        createTask(id: 1, title: 'Current'),
        createTask(id: 2, title: 'Only local'),
      ];
      final importedTasks = [
        createTask(id: 1, title: 'Imported'),
        createTask(id: 3, title: 'Only imported'),
      ];
      final snapshot = FlowDoBackupService.buildSnapshot(
        tasks: importedTasks,
        categories: CategoryItem.defaults(),
      );

      final result = FlowDoBackupService.applyImport(
        snapshot: snapshot,
        currentTasks: currentTasks,
        currentCategories: CategoryItem.defaults(),
        currentLastRegistrationCategoryId: 'work',
        mode: FlowDoImportMode.merge,
      );

      expect(result.tasks.map((task) => task.id).toSet(), {1, 2, 3});
      expect(result.tasks.firstWhere((task) => task.id == 1).title, 'Imported');
      expect(result.importedTaskCount, 2);
    });

    test('置き換えインポートは現在のタスクを上書きする', () {
      final currentTasks = [
        createTask(id: 1, title: 'Current'),
        createTask(id: 2, title: 'Local only'),
      ];
      final importedTasks = [createTask(id: 10, title: 'Fresh')];
      final snapshot = FlowDoBackupService.buildSnapshot(
        tasks: importedTasks,
        categories: CategoryItem.defaults(),
      );

      final result = FlowDoBackupService.applyImport(
        snapshot: snapshot,
        currentTasks: currentTasks,
        currentCategories: CategoryItem.defaults(),
        currentLastRegistrationCategoryId: null,
        mode: FlowDoImportMode.replace,
      );

      expect(result.tasks.length, 1);
      expect(result.tasks.single.id, 10);
      expect(result.tasks.single.title, 'Fresh');
    });

    test('存在しない categoryId は未分類へ補正する', () {
      final snapshot = FlowDoBackupService.buildSnapshot(
        tasks: [
          createTask(id: 1, title: 'Orphan', categoryId: 'missing'),
        ],
        categories: CategoryItem.defaults(),
      );

      final result = FlowDoBackupService.applyImport(
        snapshot: snapshot,
        currentTasks: const [],
        currentCategories: CategoryItem.defaults(),
        currentLastRegistrationCategoryId: null,
        mode: FlowDoImportMode.replace,
      );

      expect(
        result.tasks.single.categoryId,
        CategoryItem.uncategorizedId,
      );
    });

    test('未対応 schemaVersion は拒否する', () {
      final payload = jsonEncode({
        'schemaVersion': 99,
        'exportedAt': DateTime.utc(2026, 8, 12).toIso8601String(),
        'source': 'local',
        'payload': {
          'tasks': [],
          'categories': [],
        },
      });

      expect(
        () => FlowDoBackupService.decodeSnapshot(payload),
        throwsFormatException,
      );
    });

    test('ファイル名に日時を含める', () {
      final name = FlowDoBackupService.suggestedFileName(
        DateTime(2026, 8, 12, 9, 5),
      );
      expect(name, 'flowdo-backup-20260812-0905.json');
    });
  });
}

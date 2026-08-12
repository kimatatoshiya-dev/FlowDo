import 'category_item.dart';
import 'task.dart';
import '../utils/json_read.dart';

/// FlowDo のエクスポート／同期用データスナップショット。
///
/// iCloud 等への拡張時も同一 JSON エンベロープを利用する。
class FlowDoDataSnapshot {
  const FlowDoDataSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.source,
    required this.payload,
    this.revision,
    this.deviceId,
  });

  static const currentSchemaVersion = 1;
  static const supportedSchemaVersions = {1};

  final int schemaVersion;
  final DateTime exportedAt;

  /// データ源（`local` / 将来 `icloud` 等）
  final String source;
  final FlowDoDataPayload payload;

  /// 将来の iCloud 同期向けメタデータ（v1 では省略可）
  final int? revision;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'source': source,
        if (revision != null) 'revision': revision,
        if (deviceId != null) 'deviceId': deviceId,
        'payload': payload.toJson(),
      };

  factory FlowDoDataSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = JsonRead.integer(json['schemaVersion']);
    if (schemaVersion == null ||
        !supportedSchemaVersions.contains(schemaVersion)) {
      throw FormatException(
        'Unsupported schemaVersion: $schemaVersion',
      );
    }

    final exportedAtRaw = JsonRead.string(json['exportedAt']);
    if (exportedAtRaw == null) {
      throw const FormatException('Missing exportedAt');
    }

    final exportedAt = DateTime.tryParse(exportedAtRaw);
    if (exportedAt == null) {
      throw FormatException('Invalid exportedAt: $exportedAtRaw');
    }

    final payloadRaw = json['payload'];
    if (payloadRaw is! Map) {
      throw const FormatException('Missing payload object');
    }

    return FlowDoDataSnapshot(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      source: JsonRead.string(json['source']) ?? 'unknown',
      revision: JsonRead.integer(json['revision']),
      deviceId: JsonRead.string(json['deviceId']),
      payload: FlowDoDataPayload.fromJson(
        Map<String, dynamic>.from(payloadRaw),
      ),
    );
  }
}

/// スナップショット本体（タスク・カテゴリー等）
class FlowDoDataPayload {
  const FlowDoDataPayload({
    required this.tasks,
    required this.categories,
    this.lastRegistrationCategoryId,
  });

  final List<Task> tasks;
  final List<CategoryItem> categories;
  final String? lastRegistrationCategoryId;

  Map<String, dynamic> toJson() => {
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'categories': categories.map((category) => category.toJson()).toList(),
        if (lastRegistrationCategoryId != null)
          'lastRegistrationCategoryId': lastRegistrationCategoryId,
      };

  factory FlowDoDataPayload.fromJson(Map<String, dynamic> json) {
    final tasks = _parseTasks(json['tasks']);
    final categories = _parseCategories(json['categories']);

    return FlowDoDataPayload(
      tasks: tasks,
      categories: categories,
      lastRegistrationCategoryId:
          JsonRead.string(json['lastRegistrationCategoryId']),
    );
  }

  static List<Task> _parseTasks(Object? raw) {
    if (raw is! List) return const [];

    final tasks = <Task>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return tasks;
  }

  static List<CategoryItem> _parseCategories(Object? raw) {
    if (raw is! List) return CategoryItem.defaults();

    final categories = <CategoryItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        categories.add(
          CategoryItem.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }

    if (categories.isEmpty) return CategoryItem.defaults();
    return CategoryItem.ensureRegistrationDefaults(categories);
  }
}

import 'category_item.dart';
import 'task_priority.dart';
import '../utils/json_read.dart';

/// タスク1件分のデータモデル
class Task {
  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.isInbox = true,
    this.categoryId = CategoryItem.uncategorizedId,
    this.priorityStars = TaskPriorityStars.none,
    this.isFavorite = false,
    this.pinnedAt,
    this.dueDate,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int id;
  String title;
  bool isCompleted;
  bool isInbox;
  String categoryId;
  int priorityStars;
  bool isFavorite;
  DateTime? pinnedAt;
  DateTime? dueDate;
  DateTime? completedAt;
  final DateTime createdAt;

  static int _nextId = 0;

  /// 新しいタスクを生成する（最近追加エリアへ追加）
  factory Task.create({
    required String title,
    required String categoryId,
  }) {
    return Task(
      id: _nextId++,
      title: title,
      isInbox: true,
      categoryId: categoryId,
    );
  }

  static void syncNextId(List<Task> tasks) {
    if (tasks.isEmpty) {
      _nextId = 0;
      return;
    }
    _nextId = tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return _dateOnly(dueDate!).isBefore(_today);
  }

  bool get isDueToday {
    if (dueDate == null || isCompleted) return false;
    return _dateOnly(dueDate!) == _today;
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query.toLowerCase());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'isInbox': isInbox,
        'categoryId': categoryId,
        'priorityStars': priorityStars,
        'isFavorite': isFavorite,
        'pinnedAt': pinnedAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? dueDate;
    final dueDateRaw = JsonRead.string(json['dueDate']);
    if (dueDateRaw != null) {
      dueDate = DateTime.tryParse(dueDateRaw);
    }

    DateTime? completedAt;
    final completedAtRaw = JsonRead.string(json['completedAt']);
    if (completedAtRaw != null) {
      completedAt = DateTime.tryParse(completedAtRaw);
    }

    DateTime createdAt = DateTime.now();
    final createdAtRaw = JsonRead.string(json['createdAt']);
    if (createdAtRaw != null) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
    }

    // 旧フォーマットからの移行
    var categoryId = JsonRead.string(json['categoryId']) ??
        _migrateCategoryId(JsonRead.string(json['category']));
    if (categoryId.isEmpty) {
      categoryId = CategoryItem.uncategorizedId;
    }

    var priorityStars = JsonRead.integer(json['priorityStars']);
    priorityStars ??= TaskPriorityStars.fromLegacyName(
      JsonRead.string(json['priority']),
    );

    final id = JsonRead.integer(json['id']);
    final title = JsonRead.string(json['title']);
    if (id == null || title == null) {
      throw FormatException('Task requires id and title: $json');
    }

    DateTime? pinnedAt;
    final pinnedAtRaw = JsonRead.string(json['pinnedAt']);
    if (pinnedAtRaw != null) {
      pinnedAt = DateTime.tryParse(pinnedAtRaw);
    }

    final isFavorite = json['isFavorite'] as bool? ?? false;
    // 旧データ: 固定済みだが pinnedAt がない場合は作成日時で順序を安定化
    if (isFavorite && pinnedAt == null) {
      pinnedAt = createdAt;
    }

    return Task(
      id: id,
      title: title,
      isCompleted: json['isCompleted'] as bool? ?? false,
      // 既存タスクは整理済みとして扱う
      isInbox: json['isInbox'] as bool? ?? false,
      categoryId: categoryId,
      priorityStars: priorityStars.clamp(0, TaskPriorityStars.max),
      isFavorite: isFavorite,
      pinnedAt: pinnedAt,
      dueDate: dueDate,
      completedAt: completedAt,
      createdAt: createdAt,
    );
  }

  static String _migrateCategoryId(String? legacy) {
    return switch (legacy) {
      'work' => 'work',
      'personal' => 'personal',
      _ => CategoryItem.uncategorizedId,
    };
  }
}

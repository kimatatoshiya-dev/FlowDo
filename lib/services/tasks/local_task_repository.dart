import 'dart:async';

import '../../models/task.dart';
import '../../debug/startup_trace.dart';
import '../app_storage.dart';
import 'task_repository.dart';

/// SharedPreferences ベースのタスク永続化（オフライン / フォールバック）
class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository();

  final StreamController<List<Task>> _tasksController =
      StreamController<List<Task>>.broadcast(sync: true);

  bool _hasSeededStream = false;

  List<Task>? _memoryTasks;

  @override
  Stream<List<Task>> watchTasks() async* {
    startupTrace('LocalTaskRepository.watchTasks() entered');
    if (!_hasSeededStream) {
      _hasSeededStream = true;
      startupTrace('LocalTaskRepository.loadTasks() seeding stream');
      yield await loadTasks();
      startupTrace('LocalTaskRepository.loadTasks() seed done');
    }
    yield* _tasksController.stream;
  }

  @override
  Future<List<Task>> loadTasks() async {
    if (_memoryTasks != null) {
      return List<Task>.from(_memoryTasks!);
    }
    startupTrace('LocalTaskRepository.loadTasks() starting');
    final tasks = await AppStorage.loadTasks();
    _memoryTasks = tasks;
    startupTrace('LocalTaskRepository.loadTasks() done', '${tasks.length} task(s)');
    return List<Task>.from(tasks);
  }

  @override
  Future<void> createTask(Task task) async {
    final tasks = await loadTasks();
    tasks.insert(0, task);
    Task.syncNextId(tasks);
    await _persist(tasks);
  }

  @override
  Future<void> updateTask(Task task) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      tasks.insert(0, task);
    } else {
      final stored = tasks[index];
      stored
        ..title = task.title
        ..isCompleted = task.isCompleted
        ..isInbox = task.isInbox
        ..categoryId = task.categoryId
        ..priorityStars = task.priorityStars
        ..dueDate = task.dueDate
        ..reminderTime = task.reminderTime
        ..completedAt = task.completedAt
        ..isFavorite = task.isFavorite
        ..pinnedAt = task.pinnedAt;
    }
    Task.syncNextId(tasks);
    await _persist(tasks);
  }

  @override
  Future<void> deleteTask(int taskId) async {
    final tasks = await loadTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _persist(tasks);
  }

  @override
  Future<void> syncTasks(List<Task> tasks) async {
    final copy = List<Task>.from(tasks);
    Task.syncNextId(copy);
    await _persist(copy);
  }

  Future<void> _persist(List<Task> tasks) async {
    _memoryTasks = List<Task>.from(tasks);
    await AppStorage.saveTasks(tasks);
    if (!_tasksController.isClosed) {
      _tasksController.add(List<Task>.from(_memoryTasks!));
    }
  }
}

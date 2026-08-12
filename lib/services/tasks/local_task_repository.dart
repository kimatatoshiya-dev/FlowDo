import 'dart:async';

import '../../models/task.dart';
import '../../debug/flowdo_home_loop_diag.dart';
import '../../debug/startup_trace.dart';
import '../../debug/task_persistence_diag.dart';
import '../app_storage.dart';
import '../../debug/task_storage_log.dart';
import 'task_repository.dart';

/// SharedPreferences ベースのタスク永続化（オフライン / フォールバック）
class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository();

  final StreamController<List<Task>> _tasksController =
      StreamController<List<Task>>.broadcast();

  bool _hasSeededStream = false;

  List<Task>? _memoryTasks;

  /// 診断用: メモリ上のタスク件数（未ロード時は -1）
  int get memoryTaskCount => _memoryTasks?.length ?? -1;

  @override
  Stream<List<Task>> watchTasks() async* {
    FlowDoHomeLoopDiag.onWatchTasksEnter();
    startupTrace('LocalTaskRepository.watchTasks() entered');
    if (!_hasSeededStream) {
      _hasSeededStream = true;
      // ホーム画面を先に描画するため、空リストを即座に流してから読み込む。
      yield const [];
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
    final ready = await AppStorage.ensureReady();
    if (!ready) {
      startupTrace('LocalTaskRepository.loadTasks() aborted', 'storage not ready');
      // 未ロード状態を維持（memoryTaskCount=-1）。ensureReady 失敗時に空キャッシュを
      // 立てないことで、後続の loadTasks が再試行できる。
      return const [];
    }
    final tasks = await AppStorage.loadTasks(
      forceRetry: true,
      diagSource: 'LocalTaskRepository.loadTasks',
      logStartupDiag: true,
    );
    _memoryTasks = List<Task>.from(tasks);
    startupTrace(
      'LocalTaskRepository.loadTasks() done',
      '${tasks.length} task(s), storageReady=${AppStorage.isStorageReady}',
    );
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
    final ready = await AppStorage.ensureReady();
    if (!ready) {
      logTaskStorage('_persist skipped: storage not ready');
      return;
    }

    _memoryTasks = List<Task>.from(tasks);
    await AppStorage.saveTasks(tasks);
    logDiagRepositoryMemoryAfterSave(memoryTaskCount: _memoryTasks!.length);
    if (!_tasksController.isClosed) {
      _tasksController.add(List<Task>.from(_memoryTasks!));
    }
  }

  /// 開発中の hot restart 後など、メモリキャッシュを破棄してディスクから再読込する
  void invalidateMemoryCache() {
    _memoryTasks = null;
    _hasSeededStream = false;
  }
}

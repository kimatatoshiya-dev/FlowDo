import 'dart:async';

import 'package:flutter/foundation.dart';

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
  bool _hasLoadedFromDisk = false;

  List<Task>? _memoryTasks;

  /// 診断用: メモリ上のタスク件数（未ロード時は -1）
  int get memoryTaskCount => _memoryTasks?.length ?? -1;

  /// 診断・テスト用: 初回ディスクロード完了フラグ
  @visibleForTesting
  bool get hasLoadedFromDiskForTesting => _hasLoadedFromDisk;

  @override
  Stream<List<Task>> watchTasks() async* {
    FlowDoHomeLoopDiag.onWatchTasksEnter();
    startupTrace('LocalTaskRepository.watchTasks() entered');
    if (!_hasSeededStream) {
      _hasSeededStream = true;
      // コールド起動レース回避: 空リストを先に流さず、ディスク読込後に初回イベントを出す。
      startupTrace('LocalTaskRepository.loadTasks() loading before first yield');
      var loaded = await loadTasks();
      if (!_hasLoadedFromDisk) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        loaded = await loadTasks();
      }
      yield loaded;
      startupTrace('LocalTaskRepository.loadTasks() seed done');
    }
    yield* _tasksController.stream;
  }

  @override
  Future<List<Task>> loadTasks() async {
    logDiagLoadPipeline(
      'L1',
      'LocalTaskRepository.loadTasks entered memoryCached=${_memoryTasks != null}',
    );
    if (_memoryTasks != null) {
      return List<Task>.from(_memoryTasks!);
    }
    startupTrace('LocalTaskRepository.loadTasks() starting');
    logDiagLoadPipeline('L2', 'LocalTaskRepository.loadTasks before ensureReady');
    final ready = await AppStorage.ensureReady();
    logDiagLoadPipeline(
      'L3',
      'LocalTaskRepository.loadTasks after ensureReady ready=$ready',
    );
    if (!ready) {
      startupTrace('LocalTaskRepository.loadTasks() aborted', 'storage not ready');
      logDiagEnsureReadyResult(
        ready: false,
        attempt: -1,
        phase: 'LocalTaskRepository.loadTasks',
      );
      // 未ロード状態を維持（memoryTaskCount=-1）。ensureReady 失敗時に空キャッシュを
      // 立てないことで、後続の loadTasks が再試行できる。
      return const [];
    }
    logDiagLoadPipeline(
      'L4',
      'LocalTaskRepository.loadTasks before AppStorage.loadTasks',
    );
    final tasks = await AppStorage.loadTasks(
      forceRetry: true,
      diagSource: 'LocalTaskRepository.loadTasks',
      logStartupDiag: true,
    );
    logDiagLoadPipeline(
      'L5',
      'LocalTaskRepository.loadTasks after AppStorage.loadTasks taskCount=${tasks.length}',
    );
    _memoryTasks = List<Task>.from(tasks);
    _hasLoadedFromDisk = true;
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
    if (!_hasLoadedFromDisk) {
      logDiagSyncBeforeInitialLoad(
        incomingTaskCount: tasks.length,
        caller: 'LocalTaskRepository.syncTasks',
      );
      final copy = List<Task>.from(tasks);
      Task.syncNextId(copy);
      await _persist(copy);
      return;
    }

    if (tasks.isEmpty) {
      final diskTasks = await AppStorage.loadTasks(
        forceRetry: true,
        diagSource: 'LocalTaskRepository.syncTasks empty guard',
      );
      if (diskTasks.isNotEmpty) {
        logTaskStorage('syncTasks skipped: refusing empty sync over disk data');
        return;
      }
    }

    final copy = List<Task>.from(tasks);
    Task.syncNextId(copy);
    await _persist(copy);
  }

  Future<void> _persist(List<Task> tasks) async {
    if (!_hasLoadedFromDisk) {
      logDiagSyncBeforeInitialLoad(
        incomingTaskCount: tasks.length,
        caller: 'LocalTaskRepository._persist',
      );
      final ready = await AppStorage.ensureReady();
      if (!ready) {
        logTaskStorage('_persist skipped: storage not ready (pre-load)');
        return;
      }
      final diskTasks = await AppStorage.loadTasks(
        forceRetry: true,
        diagSource: 'LocalTaskRepository._persist preload',
      );
      _memoryTasks = List<Task>.from(diskTasks);
      _hasLoadedFromDisk = true;
      if (tasks.isEmpty && diskTasks.isNotEmpty) {
        logTaskStorage('_persist skipped: refusing empty sync over disk data');
        if (!_tasksController.isClosed) {
          _tasksController.add(List<Task>.from(diskTasks));
        }
        return;
      }
      if (diskTasks.isNotEmpty) {
        tasks = _mergeWithDiskTasks(diskTasks, tasks);
      }
    }

    final ready = await AppStorage.ensureReady();
    if (!ready) {
      logTaskStorage('_persist skipped: storage not ready');
      return;
    }

    final allowEmptyOverwrite =
        tasks.isEmpty && (_memoryTasks?.isNotEmpty ?? false);
    if (tasks.isEmpty && !allowEmptyOverwrite) {
      final diskTasks = await AppStorage.loadTasks(
        forceRetry: true,
        diagSource: 'LocalTaskRepository._persist empty guard',
      );
      if (diskTasks.isNotEmpty) {
        logTaskStorage('_persist skipped: refusing empty save over disk data');
        return;
      }
    }

    _memoryTasks = List<Task>.from(tasks);
    await AppStorage.saveTasks(
      tasks,
      allowEmptyOverwrite: allowEmptyOverwrite,
    );
    logDiagRepositoryMemoryAfterSave(memoryTaskCount: _memoryTasks!.length);
    if (!_tasksController.isClosed) {
      _tasksController.add(List<Task>.from(_memoryTasks!));
    }
  }

  /// 初回ロード前の部分リストをディスク上の既存タスクと統合する
  List<Task> _mergeWithDiskTasks(List<Task> diskTasks, List<Task> incoming) {
    if (incoming.isEmpty) return diskTasks;
    final merged = List<Task>.from(diskTasks);
    for (final task in incoming) {
      final index = merged.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        merged[index] = task;
      } else {
        merged.add(task);
      }
    }
    Task.syncNextId(merged);
    return merged;
  }

  /// 開発中の hot restart 後など、メモリキャッシュを破棄してディスクから再読込する
  void invalidateMemoryCache() {
    _memoryTasks = null;
    _hasLoadedFromDisk = false;
    _hasSeededStream = false;
  }
}

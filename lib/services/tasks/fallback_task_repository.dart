import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/task.dart';
import '../auth/auth_user.dart';
import '../../debug/startup_trace.dart';
import 'guest_task_migration.dart';
import 'task_repository.dart';

const Duration _remoteTaskTimeout = Duration(seconds: 15);

/// Firestore を優先し、失敗時はローカル永続化へフォールバックする
class FallbackTaskRepository implements TaskRepository {
  FallbackTaskRepository({
    required TaskRepository primary,
    required TaskRepository fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final TaskRepository _primary;
  final TaskRepository _fallback;

  @override
  Stream<List<Task>> watchTasks() async* {
    startupTrace('FallbackTaskRepository.watchTasks() entered');

    try {
      startupTrace('FallbackTaskRepository primary.loadTasks() starting');

      yield await _withTimeout(_primary.loadTasks());

      startupTrace('FallbackTaskRepository primary.loadTasks() done');
      startupTrace('FallbackTaskRepository primary.watchTasks() starting');

      yield* _primary.watchTasks();
    } catch (error, stackTrace) {
      startupTrace(
        'FallbackTaskRepository.watchTasks() primary FAILED',
        error,
      );

      _logFallback('watchTasks', error, stackTrace);

      startupTrace(
        'FallbackTaskRepository fallback.loadTasks() starting',
      );

      yield await _fallback.loadTasks();

      startupTrace(
        'FallbackTaskRepository fallback.loadTasks() done',
      );

      yield* _fallback.watchTasks();
    }
  }

  @override
  Future<List<Task>> loadTasks() => _run(
        'loadTasks',
        () => _primary.loadTasks(),
        () => _fallback.loadTasks(),
      );

  @override
  Future<void> createTask(Task task) => _runVoid(
        'createTask',
        () => _primary.createTask(task),
        () => _fallback.createTask(task),
      );

  @override
  Future<void> updateTask(Task task) async {
    try {
      await _withTimeout(_primary.updateTask(task));
      await _fallback.updateTask(task);
    } catch (error, stackTrace) {
      _logFallback('updateTask', error, stackTrace);
      await _fallback.updateTask(task);
    }
  }

  @override
  Future<void> deleteTask(int taskId) => _runVoid(
        'deleteTask',
        () => _primary.deleteTask(taskId),
        () => _fallback.deleteTask(taskId),
      );

  @override
  Future<void> syncTasks(List<Task> tasks) async {
    try {
      await _withTimeout(_primary.syncTasks(tasks));
      await _fallback.syncTasks(tasks);
    } catch (error, stackTrace) {
      _logFallback('syncTasks', error, stackTrace);
      await _fallback.syncTasks(tasks);
    }
  }

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      _remoteTaskTimeout,
      onTimeout: () => throw TimeoutException(
        'Firestore operation timed out after $_remoteTaskTimeout',
      ),
    );
  }

  Future<T> _run<T>(
    String operation,
    Future<T> Function() primary,
    Future<T> Function() fallback,
  ) async {
    try {
      return await _withTimeout(primary());
    } catch (error, stackTrace) {
      _logFallback(operation, error, stackTrace);
      return fallback();
    }
  }

  Future<void> _runVoid(
    String operation,
    Future<void> Function() primary,
    Future<void> Function() fallback,
  ) async {
    try {
      await _withTimeout(primary());
    } catch (error, stackTrace) {
      _logFallback(operation, error, stackTrace);
      await fallback();
    }
  }

  void _logFallback(String operation, Object error, StackTrace stackTrace) {
    debugPrint('TaskRepository fallback during $operation: $error');
    debugPrint(stackTrace.toString());
  }
}

/// 認証状態に応じて Firestore / Local を切り替える。
///
/// ゲスト利用中は [local] のみ。ログイン後は Firestore を優先し、
/// [prepareGuestDataMigration] 後の初回ログイン時にローカルデータを移行する。
class AuthAwareTaskRepository implements TaskRepository {
  AuthAwareTaskRepository({
    required TaskRepository Function(String userId) firestoreFactory,
    required TaskRepository local,
    required Stream<AuthUser?> authStateChanges,
    String? initialUserId,
  })  : _firestoreFactory = firestoreFactory,
        _local = local,
        _activeUserId = initialUserId {
    _activeRepository = _repositoryForUserId(_activeUserId);
    _authSubscription = authStateChanges.listen(_onAuthStateChanged);
  }

  final TaskRepository Function(String userId) _firestoreFactory;
  final TaskRepository _local;

  late final StreamSubscription<AuthUser?> _authSubscription;
  String? _activeUserId;
  bool _migrateGuestDataOnSignIn = false;
  TaskRepository? _activeRepository;
  StreamSubscription<List<Task>>? _activeWatchSubscription;
  final StreamController<List<Task>> _tasksController =
      StreamController<List<Task>>.broadcast();
  bool _watchInitialized = false;

  /// ゲストからログインへ切り替える直前に呼び、次回認証成功時に移行する。
  void prepareGuestDataMigration() {
    _migrateGuestDataOnSignIn = true;
  }

  @override
  Stream<List<Task>> watchTasks() async* {
    startupTrace('AuthAwareTaskRepository.watchTasks() entered');
    if (!_watchInitialized) {
      _watchInitialized = true;
      await _attachActiveWatchSubscription();
      startupTrace(
        'AuthAwareTaskRepository.watchTasks() seed done',
        '${(await _active.loadTasks()).length} task(s)',
      );
      yield await _active.loadTasks();
    }
    yield* _tasksController.stream;
  }

  @override
  Future<List<Task>> loadTasks() => _active.loadTasks();

  @override
  Future<void> createTask(Task task) => _active.createTask(task);

  @override
  Future<void> updateTask(Task task) => _active.updateTask(task);

  @override
  Future<void> deleteTask(int taskId) => _active.deleteTask(taskId);

  @override
  Future<void> syncTasks(List<Task> tasks) => _active.syncTasks(tasks);

  TaskRepository get _active => _activeRepository ?? _local;

  Future<void> _onAuthStateChanged(AuthUser? user) async {
    final nextUserId = user?.uid;
    if (nextUserId == _activeUserId) return;

    startupTrace(
      'AuthAwareTaskRepository auth changed',
      '${_activeUserId ?? 'guest'} -> ${nextUserId ?? 'guest'}',
    );

    final wasGuest = _activeUserId == null || _activeUserId!.isEmpty;
    _activeUserId = nextUserId;

    if (wasGuest &&
        nextUserId != null &&
        nextUserId.isNotEmpty &&
        _migrateGuestDataOnSignIn) {
      _migrateGuestDataOnSignIn = false;
      try {
        await GuestTaskMigration.migrateLocalTasksToRemote(
          local: _local,
          remote: _firestoreFactory(nextUserId),
        );
        startupTrace('AuthAwareTaskRepository guest migration done');
      } catch (error, stackTrace) {
        debugPrint('Guest task migration failed: $error');
        debugPrint(stackTrace.toString());
      }
    }

    _activeRepository = _repositoryForUserId(_activeUserId);
    if (_watchInitialized) {
      await _attachActiveWatchSubscription();
    }
  }

  Future<void> _attachActiveWatchSubscription() async {
    await _activeWatchSubscription?.cancel();
    final repository = _active;

    _activeWatchSubscription = repository.watchTasks().listen(
      (tasks) {
        if (!_tasksController.isClosed) {
          _tasksController.add(List<Task>.from(tasks));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('AuthAwareTaskRepository watch error: $error');
        debugPrint(stackTrace.toString());
      },
    );

    if (!_tasksController.isClosed) {
      _tasksController.add(await repository.loadTasks());
    }
  }

  TaskRepository _repositoryForUserId(String? userId) {
    if (userId == null || userId.isEmpty) {
      return _local;
    }
    return FallbackTaskRepository(
      primary: _firestoreFactory(userId),
      fallback: _local,
    );
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _activeWatchSubscription?.cancel();
    await _tasksController.close();
  }
}

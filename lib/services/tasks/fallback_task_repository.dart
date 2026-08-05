import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/task.dart';
import '../../debug/startup_trace.dart';
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

/// 認証状態に応じて Firestore / Local を切り替える
class AuthAwareTaskRepository implements TaskRepository {
  AuthAwareTaskRepository({
    required TaskRepository firestoreFactory(String userId),
    required TaskRepository local,
    required String? Function() currentUserId,
  })  : _firestoreFactory = firestoreFactory,
        _local = local,
        _currentUserId = currentUserId;

  final TaskRepository Function(String userId) _firestoreFactory;
  final TaskRepository _local;
  final String? Function() _currentUserId;

  TaskRepository get _active {
    final uid = _currentUserId();
    startupTrace('AuthAwareTaskRepository._active', 'uid=${uid ?? 'null'}');
    if (uid == null || uid.isEmpty) {
      return _local;
    }
    return FallbackTaskRepository(
      primary: _firestoreFactory(uid),
      fallback: _local,
    );
  }

  @override
  Stream<List<Task>> watchTasks() => _active.watchTasks();

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
}

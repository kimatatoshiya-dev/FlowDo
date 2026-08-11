import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/app_storage.dart';
import 'package:flowdo/services/auth/auth_user.dart';
import 'package:flowdo/services/tasks/fallback_task_repository.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';
import 'package:flowdo/services/tasks/task_repository.dart';

class _FailingTaskRepository implements TaskRepository {
  @override
  Future<void> createTask(Task task) => Future.error(Exception('primary down'));

  @override
  Future<void> deleteTask(int taskId) => Future.error(Exception('primary down'));

  @override
  Future<List<Task>> loadTasks() => Future.error(Exception('primary down'));

  @override
  Future<void> syncTasks(List<Task> tasks) =>
      Future.error(Exception('primary down'));

  @override
  Future<void> updateTask(Task task) => Future.error(Exception('primary down'));

  @override
  Stream<List<Task>> watchTasks() => Stream.error(Exception('primary down'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();
  });

  test('FallbackTaskRepository uses local repository when primary fails',
      () async {
    final repository = FallbackTaskRepository(
      primary: _FailingTaskRepository(),
      fallback: LocalTaskRepository(),
    );

    final task = Task.create(title: 'Local fallback', categoryId: 'work');
    await repository.createTask(task);

    expect((await repository.loadTasks()).single.title, 'Local fallback');
  });

  test('AuthAwareTaskRepository uses local when user is signed out', () async {
    final authController = StreamController<AuthUser?>();
    addTearDown(authController.close);

    final repository = AuthAwareTaskRepository(
      firestoreFactory: (_) => _FailingTaskRepository(),
      local: LocalTaskRepository(),
      authStateChanges: authController.stream,
      initialUserId: null,
    );

    final task = Task.create(title: 'Signed out', categoryId: 'work');
    await repository.createTask(task);

    expect((await repository.loadTasks()).single.title, 'Signed out');
  });

  test('AuthAwareTaskRepository migrates guest data after explicit sign in',
      () async {
    final authController = StreamController<AuthUser?>();
    addTearDown(authController.close);

    final local = LocalTaskRepository();
    final remote = LocalTaskRepository();
    final repository = AuthAwareTaskRepository(
      firestoreFactory: (_) => remote,
      local: local,
      authStateChanges: authController.stream,
      initialUserId: null,
    );

    await repository.createTask(
      Task.create(title: 'Guest task', categoryId: 'work'),
    );
    repository.prepareGuestDataMigration();

    authController.add(
      const AuthUser(uid: 'user-1', email: 'guest@flowdo.local'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect((await remote.loadTasks()).single.title, 'Guest task');
    expect((await local.loadTasks()).single.title, 'Guest task');
  });
}

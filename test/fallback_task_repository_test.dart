import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/app_storage.dart';
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
    final repository = AuthAwareTaskRepository(
      firestoreFactory: (_) => _FailingTaskRepository(),
      local: LocalTaskRepository(),
      currentUserId: () => null,
    );

    final task = Task.create(title: 'Signed out', categoryId: 'work');
    await repository.createTask(task);

    expect((await repository.loadTasks()).single.title, 'Signed out');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/app_storage.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.warmUp();
  });

  test('loadTasks returns empty list initially', () async {
    final repository = LocalTaskRepository();
    expect(await repository.loadTasks(), isEmpty);
  });

  test('createTask persists and emits on watchTasks', () async {
    final repository = LocalTaskRepository();
    final task = Task.create(title: 'Buy milk', categoryId: 'work');

    await repository.createTask(task);

    final loaded = await repository.loadTasks();
    expect(loaded, hasLength(1));
    expect(loaded.first.title, 'Buy milk');

    final streamValues = <List<Task>>[];
    final subscription = repository.watchTasks().listen(streamValues.add);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(streamValues, isNotEmpty);
    expect(streamValues.last.first.title, 'Buy milk');
  });

  test('updateTask and deleteTask work', () async {
    final repository = LocalTaskRepository();
    final task = Task.create(title: 'Draft', categoryId: 'work');
    await repository.createTask(task);

    task.title = 'Updated';
    await repository.updateTask(task);
    expect((await repository.loadTasks()).single.title, 'Updated');

    await repository.deleteTask(task.id);
    expect(await repository.loadTasks(), isEmpty);
  });

  test('syncTasks replaces entire list', () async {
    final repository = LocalTaskRepository();
    final first = Task.create(title: 'One', categoryId: 'work');
    final second = Task.create(title: 'Two', categoryId: 'work');
    await repository.syncTasks([first, second]);

    final loaded = await repository.loadTasks();
    expect(loaded, hasLength(2));
    expect(loaded.map((task) => task.title), ['One', 'Two']);
  });

  test('updateTask after syncTasks does not drop other tasks', () async {
    final repository = LocalTaskRepository();
    final first = Task.create(title: 'One', categoryId: 'work');
    final second = Task.create(title: 'Two', categoryId: 'work');
    await repository.syncTasks([first, second]);

    first.isFavorite = true;
    first.pinnedAt = DateTime(2026, 1, 1, 12);
    await repository.updateTask(first);

    final loaded = await repository.loadTasks();
    expect(loaded, hasLength(2));
    expect(loaded.first.title, 'One');
    expect(loaded.first.isFavorite, isTrue);
    expect(loaded.last.title, 'Two');
  });
}

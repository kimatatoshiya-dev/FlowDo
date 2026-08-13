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
    AppStorage.resetForTesting();
    await AppStorage.warmUp();
  });

  test('sync before initial load does not wipe existing disk tasks', () async {
    final existing = Task.create(title: 'Keep me', categoryId: 'work');
    await AppStorage.saveTasks([existing]);

    final repository = LocalTaskRepository();
    final incoming = Task.create(title: 'New task', categoryId: 'work');
    await repository.syncTasks([incoming]);

    final loaded = await AppStorage.loadTasks(forceRetry: true);
    expect(loaded, hasLength(2));
    expect(loaded.any((task) => task.title == 'Keep me'), isTrue);
    expect(loaded.any((task) => task.title == 'New task'), isTrue);
  });

  test('empty sync before initial load does not wipe disk', () async {
    final existing = Task.create(title: 'Survive', categoryId: 'work');
    await AppStorage.saveTasks([existing]);

    final repository = LocalTaskRepository();
    await repository.syncTasks(const []);

    final loaded = await AppStorage.loadTasks(forceRetry: true);
    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Survive');
  });

  test('cold restore 20x: save, invalidate cache, reload from disk', () async {
    for (var cycle = 1; cycle <= 20; cycle++) {
      SharedPreferences.setMockInitialValues({});
      AppStorage.resetForTesting();
      await AppStorage.warmUp();

      final marker = 'phase4-cycle-$cycle';
      final repository = LocalTaskRepository();
      await repository.createTask(
        Task.create(title: marker, categoryId: 'work'),
      );

      repository.invalidateMemoryCache();
      AppStorage.resetForTesting();
      await AppStorage.warmUp();

      final restored = await LocalTaskRepository().loadTasks();
      expect(
        restored.any((task) => task.title == marker),
        isTrue,
        reason: 'cycle $cycle failed cold restore',
      );
    }
  });
}

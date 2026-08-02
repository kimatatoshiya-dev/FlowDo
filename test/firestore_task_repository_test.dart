import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/tasks/firestore_task_repository.dart';

void main() {
  test('FirestoreTaskRepository stores tasks under users/{uid}/tasks/{taskId}',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreTaskRepository(
      userId: 'user-123',
      firestore: firestore,
    );

    final task = Task.create(title: 'Firestore task', categoryId: 'work');
    await repository.createTask(task);

    final doc = await firestore
        .collection('users')
        .doc('user-123')
        .collection('tasks')
        .doc(task.id.toString())
        .get();

    expect(doc.exists, isTrue);
    expect(doc.data()?['title'], 'Firestore task');
  });

  test('FirestoreTaskRepository supports CRUD, load, and watch', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreTaskRepository(
      userId: 'user-abc',
      firestore: firestore,
    );

    final task = Task.create(title: 'Alpha', categoryId: 'work');
    await repository.createTask(task);

    task.title = 'Beta';
    await repository.updateTask(task);
    expect((await repository.loadTasks()).single.title, 'Beta');

    final emissions = <List<Task>>[];
    final subscription = repository.watchTasks().listen(emissions.add);
    await Future<void>.delayed(Duration.zero);
    expect(emissions.last.single.title, 'Beta');

    await repository.deleteTask(task.id);
    expect(await repository.loadTasks(), isEmpty);

    await subscription.cancel();
  });

  test('syncTasks replaces remote documents', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreTaskRepository(
      userId: 'user-sync',
      firestore: firestore,
    );

    final keep = Task.create(title: 'Keep', categoryId: 'work');
    final remove = Task.create(title: 'Remove', categoryId: 'work');
    await repository.syncTasks([keep, remove]);

    final replacement = Task.create(title: 'New', categoryId: 'personal');
    await repository.syncTasks([keep, replacement]);

    final loaded = await repository.loadTasks();
    expect(loaded, hasLength(2));
    expect(
      loaded.map((task) => task.title).toSet(),
      {'Keep', 'New'},
    );
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/task.dart';
import '../../debug/startup_trace.dart';
import 'task_repository.dart';

/// Cloud Firestore 上の users/{uid}/tasks/{taskId} を操作する
class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('tasks');

  @override
  Stream<List<Task>> watchTasks() {
    startupTrace('FirestoreTaskRepository.watchTasks() stream created', 'uid=$userId');
    var purgingExpired = false;
    return _collection.orderBy('createdAt', descending: true).snapshots().asyncMap(
      (snapshot) async {
        startupTrace(
          'FirestoreTaskRepository.watchTasks() snapshot',
          'uid=$userId docs=${snapshot.docs.length}',
        );
        final tasks = _tasksFromSnapshot(snapshot);
        final retained = await TaskRepositoryRetention.filterRetained(tasks);
        await _purgeExpiredIfNeeded(
          tasks: tasks,
          retained: retained,
          purgingExpired: () => purgingExpired,
          setPurgingExpired: (value) => purgingExpired = value,
        );
        return retained;
      },
    );
  }

  @override
  Future<List<Task>> loadTasks() async {
    startupTrace('FirestoreTaskRepository.loadTasks() starting', 'uid=$userId');
    final snapshot =
        await _collection.orderBy('createdAt', descending: true).get();
    startupTrace(
      'FirestoreTaskRepository.loadTasks() done',
      'uid=$userId docs=${snapshot.docs.length}',
    );
    final tasks = _tasksFromSnapshot(snapshot);
    final retained = await TaskRepositoryRetention.filterRetained(tasks);
    await _purgeExpiredIfNeeded(
      tasks: tasks,
      retained: retained,
      purgingExpired: () => _loadPurgingExpired,
      setPurgingExpired: (value) => _loadPurgingExpired = value,
    );
    return retained;
  }

  bool _loadPurgingExpired = false;

  @override
  Future<void> createTask(Task task) async {
    final docRef = _collection.doc(_docId(task.id));
    await docRef.set(task.toJson());
    debugPrint('FirestoreTaskRepository: created ${docRef.path}');
  }

  @override
  Future<void> updateTask(Task task) async {
    await _collection.doc(_docId(task.id)).set(task.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteTask(int taskId) async {
    await _collection.doc(_docId(taskId)).delete();
  }

  @override
  Future<void> syncTasks(List<Task> tasks) async {
    final batch = _firestore.batch();
    final existing = await _collection.get();
    final desiredIds = tasks.map((task) => _docId(task.id)).toSet();

    for (final doc in existing.docs) {
      if (!desiredIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (final task in tasks) {
      batch.set(_collection.doc(_docId(task.id)), task.toJson());
    }

    await batch.commit();
    debugPrint(
      'FirestoreTaskRepository: synced ${tasks.length} task(s) to users/$userId/tasks',
    );
  }

  String _docId(int taskId) => taskId.toString();

  List<Task> _tasksFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final tasks = snapshot.docs
        .map((doc) => Task.fromJson(_taskJson(doc)))
        .toList(growable: false);
    Task.syncNextId(tasks);
    return tasks;
  }

  Future<void> _purgeExpiredIfNeeded({
    required List<Task> tasks,
    required List<Task> retained,
    required bool Function() purgingExpired,
    required void Function(bool value) setPurgingExpired,
  }) async {
    if (retained.length == tasks.length || purgingExpired()) return;

    setPurgingExpired(true);
    try {
      await syncTasks(retained);
    } finally {
      setPurgingExpired(false);
    }
  }

  Map<String, dynamic> _taskJson(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Map<String, dynamic>.from(doc.data());
  }
}

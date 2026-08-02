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
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) {
        startupTrace(
          'FirestoreTaskRepository.watchTasks() snapshot',
          'uid=$userId docs=${snapshot.docs.length}',
        );
        final tasks = snapshot.docs
            .map((doc) => Task.fromJson(doc.data()))
            .toList(growable: false);
        Task.syncNextId(tasks);
        return tasks;
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
    final tasks = snapshot.docs
        .map((doc) => Task.fromJson(doc.data()))
        .toList(growable: false);
    Task.syncNextId(tasks);
    return tasks;
  }

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
}

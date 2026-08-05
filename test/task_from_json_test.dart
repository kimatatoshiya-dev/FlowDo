import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task.dart';

void main() {
  group('Task.fromJson bool fields', () {
    test('missing bool fields default safely', () {
      final task = Task.fromJson({
        'id': 1,
        'title': 'legacy task',
      });

      expect(task.isCompleted, isFalse);
      expect(task.isInbox, isFalse);
      expect(task.isFavorite, isFalse);
    });

    test('null bool fields default safely', () {
      final task = Task.fromJson({
        'id': 2,
        'title': 'null bool task',
        'isCompleted': null,
        'isInbox': null,
        'isFavorite': null,
      });

      expect(task.isCompleted, isFalse);
      expect(task.isInbox, isFalse);
      expect(task.isFavorite, isFalse);
    });

    test('explicit bool values are preserved', () {
      final task = Task.fromJson({
        'id': 3,
        'title': 'explicit bool task',
        'isCompleted': true,
        'isInbox': true,
        'isFavorite': true,
      });

      expect(task.isCompleted, isTrue);
      expect(task.isInbox, isTrue);
      expect(task.isFavorite, isTrue);
    });
  });
}

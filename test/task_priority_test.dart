import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task_priority.dart';

void main() {
  group('TaskPriorityStars.label', () {
    test('優先度なしは ☆なし と表示する', () {
      expect(TaskPriorityStars.label(0), TaskPriorityStars.noneLabel);
    });

    test('星付き優先度は ★N 形式で表示する', () {
      expect(TaskPriorityStars.label(5), '★5');
      expect(TaskPriorityStars.label(4), '★4');
      expect(TaskPriorityStars.label(3), '★3');
      expect(TaskPriorityStars.label(2), '★2');
      expect(TaskPriorityStars.label(1), '★1');
    });
  });

  group('TaskPriorityStars.chipColors', () {
    test('優先度ごとに色を分ける', () {
      expect(TaskPriorityStars.chipColors(5).foreground, const Color(0xFFD92D20));
      expect(TaskPriorityStars.chipColors(4).foreground, const Color(0xFFE86A00));
      expect(TaskPriorityStars.chipColors(3).foreground, const Color(0xFFE6A800));
      expect(TaskPriorityStars.chipColors(2).foreground, const Color(0xFF007AFF));
      expect(TaskPriorityStars.chipColors(1).foreground, const Color(0xFFAEAEB2));
      expect(TaskPriorityStars.chipColors(0).foreground, const Color(0xFF8E8E93));
    });
  });
}

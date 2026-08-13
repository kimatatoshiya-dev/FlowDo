import 'package:flutter/material.dart';

import '../models/task_add_input.dart';
import '../models/task_edit_result.dart';
import '../theme/app_theme.dart';

/// 新規タスク追加シート（複数行入力専用）
class TaskAddSheet extends StatefulWidget {
  const TaskAddSheet({super.key});

  static Future<TaskAddInput?> show(BuildContext context) {
    return showModalBottomSheet<TaskAddInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TaskAddSheet(),
    );
  }

  @override
  State<TaskAddSheet> createState() => _TaskAddSheetState();
}

class _TaskAddSheetState extends State<TaskAddSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasValidInput() {
    return _controller.text
        .split('\n')
        .any((line) => line.trim().isNotEmpty);
  }

  void _submit() {
    if (!_hasValidInput()) return;
    Navigator.of(context).pop(TaskAddInput(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.groupedSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '新規タスク',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '1行に1件ずつ入力してください',
                ),
                maxLines: 8,
                minLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Text(
                  '改行ごとに1件のタスクとして登録されます',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.secondaryLabel,
                      ),
                ),
              ),
              FilledButton(
                onPressed: _submit,
                child: const Text('追加'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// タスク名編集シート
class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({
    super.key,
    required this.initialTitle,
    this.allowDelete = true,
  });

  final String initialTitle;
  final bool allowDelete;

  static Future<TaskEditResult?> show(
    BuildContext context, {
    required String title,
    bool allowDelete = true,
  }) {
    return showModalBottomSheet<TaskEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskEditSheet(
        initialTitle: title,
        allowDelete: allowDelete,
      ),
    );
  }

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      TaskEditSaved(title: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.groupedSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'タスクを編集',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'タスク名'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  if (widget.allowDelete) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, const TaskEditDeleted()),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      child: const Text('削除'),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

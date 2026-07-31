import 'package:flutter/material.dart';

/// カテゴリー名入力ダイアログ（Controller の生命周期を安全に管理）
Future<String?> showCategoryNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _CategoryNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'カテゴリー名'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// ダイアログ・シートのルートと Overlay が完全に閉じた後に処理を実行する
Future<void> runAfterDialogClosed(Future<void> Function() action) async {
  await _waitForUiToSettle();
  await action();
}

Future<void> _waitForUiToSettle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }
}

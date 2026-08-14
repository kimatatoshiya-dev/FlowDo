import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 日付ごとのメモ入力（自動保存）
class DailyMemoEditor extends StatefulWidget {
  const DailyMemoEditor({
    super.key,
    required this.initialText,
    required this.onSave,
    this.minHeight = 140,
    this.hintText = '今日の気付き・反省・アイデアを書きましょう',
  });

  final String initialText;
  final Future<void> Function(String text) onSave;
  final double minHeight;
  final String hintText;

  @override
  State<DailyMemoEditor> createState() => _DailyMemoEditorState();
}

class _DailyMemoEditorState extends State<DailyMemoEditor> {
  late final TextEditingController _controller;
  Timer? _saveTimer;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant DailyMemoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await widget.onSave(_controller.text);
    } finally {
      _isSaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Container(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: TextField(
        key: const ValueKey('daily_memo_field'),
        controller: _controller,
        onChanged: (_) => _scheduleSave(),
        maxLines: null,
        minLines: 5,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.45,
                color: colors.secondaryLabel.withValues(alpha: 0.85),
              ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.45,
            ),
      ),
    );
  }
}

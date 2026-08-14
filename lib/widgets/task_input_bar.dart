import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flowdo_flow_canvas.dart';
import 'flowdo_mark.dart';

/// ホーム画面常設のタスク入力欄
class TaskInputBar extends StatefulWidget {
  const TaskInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onFocusChanged,
    this.onTodayMemoTap,
    this.showGuidance = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onTodayMemoTap;
  final bool showGuidance;

  @override
  State<TaskInputBar> createState() => TaskInputBarState();
}

class TaskInputBarState extends State<TaskInputBar> {
  static const _exampleText = '例）\n牛乳\nジムへ19時に行く\n上司へ電話';

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        widget.onFocusChanged?.call(_focusNode.hasFocus);
        _rebuild();
      });
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_rebuild);
    _focusNode.dispose();
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void unfocus() => _focusNode.unfocus();

  void _rebuild() => setState(() {});

  bool get _showExample => widget.controller.text.isEmpty;

  TextStyle _captionStyle(BuildContext context, FlowDoColors colors) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          color: colors.secondaryLabel,
        );
  }

  Widget _captionRow({
    required String text,
    required double markIntensity,
    required TextStyle style,
  }) {
    return Row(
      children: [
        FlowDoMark(
          size: 18,
          intensity: markIntensity,
        ),
        const SizedBox(width: 8),
        Text(text, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isFocused = _focusNode.hasFocus;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markIntensity = isFocused ? 0.85 : 0.6;
    final captionStyle = _captionStyle(context, colors);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '頭に浮かんだことを、そのまま書き出そう。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '改行ごとに1件のタスクになります。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: colorScheme.onSurface.withValues(alpha: 0.88),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'まず全部書き出そう。整理はあとから。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.secondaryLabel,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: widget.showGuidance ? 6 : 0),
                  child: FlowDoFlowCanvas(
                    isFocused: isFocused,
                    isDark: isDark,
                    showGuidance: widget.showGuidance,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _captionRow(
                            text: '今、浮かんだこと',
                            markIntensity: markIntensity,
                            style: captionStyle,
                          ),
                          const SizedBox(height: 14),
                          Stack(
                            alignment: Alignment.topLeft,
                            children: [
                              TextField(
                                key: const ValueKey('task_input_field'),
                                controller: widget.controller,
                                focusNode: _focusNode,
                                decoration: const InputDecoration(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  hoverColor: Colors.transparent,
                                ),
                                maxLines: 8,
                                minLines: 3,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      height: 1.5,
                                      letterSpacing: -0.1,
                                    ),
                                cursorColor: colorScheme.primary,
                                cursorWidth: 1.5,
                              ),
                              if (_showExample)
                                IgnorePointer(
                                  child: Text(
                                    _exampleText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colors.secondaryLabel
                                              .withValues(alpha: 0.28),
                                          height: 1.5,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _captionRow(
                                  text: '改行でどんどん追加 → 登録',
                                  markIntensity: markIntensity,
                                  style: captionStyle,
                                ),
                              ),
                              FilledButton(
                                onPressed: widget.onSubmit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 9,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  elevation: 0,
                                ),
                                child: const Text('登録'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onTodayMemoTap != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(top: widget.showGuidance ? 6 : 0),
                  child: _TodayMemoShortcutButton(
                    onTap: widget.onTodayMemoTap!,
                  ),
                ),
              ],
            ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMemoShortcutButton extends StatelessWidget {
  const _TodayMemoShortcutButton({required this.onTap});

  static const _iosSystemGreen = Color(0xFF34C759);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.2,
    );

    return Material(
      color: _iosSystemGreen,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        key: const ValueKey('today_memo_shortcut'),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(height: 8),
                for (final character in '今日メモ'.split(''))
                  Text(character, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

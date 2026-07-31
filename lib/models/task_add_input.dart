/// タスク追加ダイアログから返す入力テキスト
class TaskAddInput {
  const TaskAddInput(this.rawText);

  final String rawText;

  /// 改行区切りのタスク名一覧（空行は除外）
  List<String> extractTitles() {
    return rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

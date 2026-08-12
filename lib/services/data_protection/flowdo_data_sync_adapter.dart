/// FlowDo データの読み書き先を抽象化する。
///
/// v1.4 ではローカル JSON ファイル、将来 iCloud 等へ差し替え可能。
abstract interface class FlowDoDataSyncAdapter {
  /// インポート用 JSON 文字列を取得する。キャンセル時は null。
  Future<String?> pickImportJson();

  /// エクスポート JSON を共有／保存する。
  Future<void> shareExportJson({
    required String json,
    required String fileName,
  });
}

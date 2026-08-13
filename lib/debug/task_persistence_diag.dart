import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// タスク永続化の原因調査用ログ（debug/release 問わず必ず出力）
const _tag = '[FlowDoPersistDiag]';

void _printDiag(String phase, String message) {
  debugPrint('$_tag$phase $message');
}

/// loadTasks パイプライン通過点（L1～L6、Profile でも必ず出力）
void logDiagLoadPipeline(String step, [String? detail]) {
  _printDiag('', '$step${detail == null ? '' : ' $detail'}');
}

/// loadTasks() の読み込み結果（診断③）
enum TaskLoadDiagOutcome {
  storageUnavailable,
  keyMissing,
  emptyPayload,
  jsonDecodeFailure,
  success,
}

/// 診断① saveTasks() の保存結果（件数・バイト数・キー）
void logDiagSaveTasksDetail({
  required String storageKey,
  required int savedTaskCount,
  required int savedPayloadBytes,
  required bool storageReady,
  required bool? setStringResult,
  required bool verified,
  required bool succeeded,
  String? errorMessage,
}) {
  _printDiag(
    '①save',
    'key=$storageKey savedTaskCount=$savedTaskCount '
    'savedPayloadBytes=$savedPayloadBytes '
    'storageReady=$storageReady '
    'setStringResult=$setStringResult '
    'verified=$verified succeeded=$succeeded'
    '${errorMessage == null ? '' : ' error=$errorMessage'}',
  );
}

/// 診断② 起動直後の SharedPreferences キー一覧（flowdo_*）
void logDiagStartupSharedPreferencesKeys({
  required Set<String> allKeys,
  required bool hasTasksKey,
  required bool hasCategoriesKey,
  required int? tasksPayloadBytes,
  required int? categoriesPayloadBytes,
}) {
  final flowdoKeys = allKeys.where((key) => key.startsWith('flowdo_')).toList()
    ..sort();
  _printDiag(
    '②keys',
    'getKeys flowdo_*=$flowdoKeys '
    'hasTasksKey=$hasTasksKey tasksPayloadBytes=$tasksPayloadBytes '
    'hasCategoriesKey=$hasCategoriesKey categoriesPayloadBytes=$categoriesPayloadBytes',
  );
}

/// 診断③ loadTasks() の結果判別
void logDiagLoadTasksOutcome({
  required String source,
  required TaskLoadDiagOutcome outcome,
  required bool storageReady,
  required int taskCount,
  int? payloadBytes,
  String? errorMessage,
}) {
  _printDiag(
    '③load',
    'source=$source outcome=${outcome.name} storageReady=$storageReady '
    'taskCount=$taskCount payloadBytes=$payloadBytes'
    '${errorMessage == null ? '' : ' error=$errorMessage'}',
  );
}

/// ① タスク追加直後（saveTasks 完了時・後方互換）
void logDiagAfterSaveTasks({
  required int savedTaskCount,
  required bool storageReady,
  required bool? setStringResult,
  required bool verified,
  String? errorMessage,
}) {
  logDiagSaveTasksDetail(
    storageKey: 'flowdo_tasks',
    savedTaskCount: savedTaskCount,
    savedPayloadBytes: 0,
    storageReady: storageReady,
    setStringResult: setStringResult,
    verified: verified,
    succeeded: (setStringResult ?? false) && verified && errorMessage == null,
    errorMessage: errorMessage,
  );
}

/// ① 補助: Repository メモリ上の件数（saveTasks 直後）
void logDiagRepositoryMemoryAfterSave({
  required int memoryTaskCount,
}) {
  _printDiag('①', 'repositoryMemoryTaskCount=$memoryTaskCount');
}

/// ① 危険: 空リスト保存が既存データを上書きしうる
void logDiagEmptySaveAttempt({
  required int incomingTaskCount,
  required int existingPayloadBytes,
  required String caller,
}) {
  _printDiag(
    '⚠️',
    'saveTasks empty/risky incoming=$incomingTaskCount '
    'existingPayloadBytes=$existingPayloadBytes caller=$caller',
  );
}

/// ① 危険: 初回 load 前に sync が走った
void logDiagSyncBeforeInitialLoad({
  required int incomingTaskCount,
  required String caller,
}) {
  _printDiag(
    '⚠️',
    'syncTasks before initial load incoming=$incomingTaskCount caller=$caller',
  );
}

/// ③ ensureReady 結果
void logDiagEnsureReadyResult({
  required bool ready,
  required int attempt,
  required String phase,
}) {
  _printDiag(
    '③',
    'ensureReady phase=$phase ready=$ready attempt=$attempt',
  );
}

/// ② アプリ終了前（バックグラウンド/終了直前）
void logDiagBeforeAppExit({
  required AppLifecycleState lifecycleState,
  required int repositoryMemoryTaskCount,
  required int homePageTaskCount,
}) {
  _printDiag(
    '②',
    'lifecycle=$lifecycleState '
    'repositoryMemoryTaskCount=$repositoryMemoryTaskCount '
    'homePageTaskCount=$homePageTaskCount',
  );
}

/// ③ 次回起動時（SharedPreferences 読み込み直後）
void logDiagStartupLoad({
  required String source,
  required bool storageReady,
  required bool hadPersistedPayload,
  required int? payloadBytes,
  required int taskCount,
  required String rawJson,
  String? errorMessage,
}) {
  _printDiag(
    '③',
    'source=$source storageReady=$storageReady '
    'hadPersistedPayload=$hadPersistedPayload '
    'payloadBytes=$payloadBytes taskCount=$taskCount'
    '${errorMessage == null ? '' : ' error=$errorMessage'}',
  );
  _printDiag('③', 'rawJson=$rawJson');
}

/// ④ UI 反映直前
void logDiagBeforeUiApply({
  required int repositoryTaskCount,
  required int homePageTaskCountBefore,
  required int retainedTaskCount,
  required int homePageTaskCountAfter,
  required bool isInitialLoad,
}) {
  _printDiag(
    '④',
    'isInitialLoad=$isInitialLoad '
    'repositoryTaskCount=$repositoryTaskCount '
    'homePageTaskCountBefore=$homePageTaskCountBefore '
    'retainedTaskCount=$retainedTaskCount '
    'homePageTaskCountAfter=$homePageTaskCountAfter',
  );
}

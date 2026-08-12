import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// タスク永続化の原因調査用ログ（debug/release 問わず必ず出力）
const _tag = '[FlowDoPersistDiag]';

void _printDiag(String phase, String message) {
  debugPrint('$_tag$phase $message');
}

/// ① タスク追加直後（saveTasks 完了時）
void logDiagAfterSaveTasks({
  required int savedTaskCount,
  required bool storageReady,
  required bool? setStringResult,
  required bool verified,
  String? errorMessage,
}) {
  _printDiag(
    '①',
    'saveTasks() savedTaskCount=$savedTaskCount '
    'storageReady=$storageReady '
    'setStringResult=$setStringResult '
    'verified=$verified'
    '${errorMessage == null ? '' : ' error=$errorMessage'}',
  );
}

/// ① 補助: Repository メモリ上の件数（saveTasks 直後）
void logDiagRepositoryMemoryAfterSave({
  required int memoryTaskCount,
}) {
  _printDiag('①', 'repositoryMemoryTaskCount=$memoryTaskCount');
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

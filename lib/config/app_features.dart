/// 無料版 / 有料版の機能フラグ。
///
/// 有料版リリース時は各フラグを true に切り替える。
library;

/// AI 整理（OpenAI）。
const kAiOrganizeEnabled = false;

/// Firebase（Analytics / Crashlytics / Auth / Firestore）の機能利用。
/// false でも iOS ネイティブ SDK 同梱のため Core 初期化は行い、送信のみ無効化する。
const kFirebaseEnabled = false;

/// クラウド認証・同期（Google / Apple ログイン、Firestore）。
/// [kFirebaseEnabled] が true のときのみ有効。
const kCloudAuthEnabled = false;

/// ログイン画面をスキップして即ホーム表示。
const kGuestModeEnabled = true;

/// タスク通知（flutter_local_notifications）。
///
/// 起動障害の切り分け用フラグ。lazy init + 安全 AppDelegate と組み合わせて利用。
const kTaskNotificationsEnabled = false;

// 将来機能: カテゴリーフィルターでの複数グループ同時表示（今回は未実装）。

/// 有料版向けバックエンド（Firebase + クラウド同期）が有効か。
bool get kPaidTierBackendEnabled => kFirebaseEnabled && kCloudAuthEnabled;

/// アプリのキャッチコピー。
String get kAppTagline => kAiOrganizeEnabled
    ? '考えずに入力。整理はAI。行動に集中。'
    : '考えずに入力。行動に集中。';

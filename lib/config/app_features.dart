/// 無料版 / 有料版の機能フラグ。
///
/// 有料版リリース時は各フラグを true に切り替える。
library;

/// AI 整理（OpenAI）。
const kAiOrganizeEnabled = false;

/// Firebase（Analytics / Crashlytics / Auth / Firestore）。
const kFirebaseEnabled = false;

/// クラウド認証・同期（Google / Apple ログイン、Firestore）。
/// [kFirebaseEnabled] が true のときのみ有効。
const kCloudAuthEnabled = false;

/// ログイン画面をスキップして即ホーム表示。
const kGuestModeEnabled = true;

/// 有料版向けバックエンド（Firebase + クラウド同期）が有効か。
bool get kPaidTierBackendEnabled => kFirebaseEnabled && kCloudAuthEnabled;

/// アプリのキャッチコピー。
String get kAppTagline => kAiOrganizeEnabled
    ? '考えずに入力。整理はAI。行動に集中。'
    : '考えずに入力。行動に集中。';

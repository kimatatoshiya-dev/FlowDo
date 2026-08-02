import Foundation

#if DEBUG
/// Firebase Analytics DebugView 用の Debug Mode を有効化する。
///
/// UserDefaults を Firebase 初期化前に設定する。ProcessInfo.arguments の
/// KVC 書き換えは iOS 26 以降で単体起動を阻害するため行わない。
enum FirebaseAnalyticsDebugMode {
  static func enableIfNeeded() {
    UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
    UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
  }
}
#endif

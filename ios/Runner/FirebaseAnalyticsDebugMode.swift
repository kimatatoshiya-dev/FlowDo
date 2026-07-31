import Foundation

#if DEBUG
/// Firebase Analytics DebugView 用の Debug Mode を有効化する。
///
/// `flutter run` では Xcode スキームの起動引数が渡らないことがあるため、
/// Firebase 初期化前に ProcessInfo へ引数を注入する。
enum FirebaseAnalyticsDebugMode {
  private static let firebaseDebugDefaultsKey = "/google/firebase/debug_mode"
  private static let launchArguments = [
    "-FIRDebugEnabled",
    "-FIRAnalyticsDebugEnabled",
  ]

  static func enableIfNeeded() {
    UserDefaults.standard.set(true, forKey: firebaseDebugDefaultsKey)

    var arguments = ProcessInfo.processInfo.arguments
    var changed = false
    for flag in launchArguments where !arguments.contains(flag) {
      arguments.append(flag)
      changed = true
    }
    guard changed else { return }
    ProcessInfo.processInfo.setValue(arguments, forKey: "arguments")
  }
}
#endif

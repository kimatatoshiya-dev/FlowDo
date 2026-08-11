import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // WORKAROUND(ios-launch): Flutter #153971 / #187544 向け。
    // 公式 Engine 修正後は FlowDoLaunchPrewarm モジュールごと削除（FlowDoLaunchPrewarm.h 参照）。
    FlowDoPrewarmLaunchEngine(self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

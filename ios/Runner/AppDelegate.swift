import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override init() {
    super.init()
    NSLog("[FlowDoNativeStartup] AppDelegate.init start")
    NSLog("[FlowDoNativeStartup] AppDelegate.init end")
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSLog("[FlowDoNativeStartup] AppDelegate.didFinishLaunching start")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    NSLog("%@", "[FlowDoNativeStartup] AppDelegate.didFinishLaunching end result=\(result)")
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    NSLog("[FlowDoNativeStartup] AppDelegate.didInitializeImplicitFlutterEngine start")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    NSLog("[FlowDoNativeStartup] AppDelegate.didInitializeImplicitFlutterEngine plugins registered")
  }
}

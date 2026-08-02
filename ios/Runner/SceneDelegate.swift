import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    NSLog("[FlowDoNativeStartup] SceneDelegate.willConnect start configuration=\(session.configuration.name)")
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    NSLog("[FlowDoNativeStartup] SceneDelegate.willConnect end")
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    NSLog("[FlowDoNativeStartup] SceneDelegate.sceneDidBecomeActive")
    super.sceneDidBecomeActive(scene)
  }
}

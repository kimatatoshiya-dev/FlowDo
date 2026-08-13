#import <Flutter/Flutter.h>

/// Storyboard 上の FlutterViewController が awake する前に launch engine を生成する。
/// iOS 26 + ProMotion の VSyncClient 起動クラッシュ回避（flutter#153971）。
void FlowDoPrewarmLaunchEngine(FlutterAppDelegate *delegate);

/// launch engine の shell 作成後、FlutterImplicitEngineDelegate 経由で
/// GeneratedPluginRegistrant.register を 1 回だけ実行する。
void FlowDoRegisterImplicitPluginsOnce(FlutterAppDelegate *delegate);

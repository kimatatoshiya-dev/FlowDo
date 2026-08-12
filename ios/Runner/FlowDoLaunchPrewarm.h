#import <Flutter/Flutter.h>

// FlowDo iOS 起動ワークアラウンド（Flutter 公式修正待ち）
//
// 【背景】
// iOS 26 + ProMotion 端末で、Storyboard 経由の FlutterViewController が
// Engine 初期化前に viewDidLoad へ進み、VSyncClient で SIGSEGV する既知問題への対処。
//   - https://github.com/flutter/flutter/issues/153971
//   - https://github.com/flutter/flutter/issues/187544
//   - https://github.com/flutter/flutter/issues/187565
//
// 【Flutter アップデートで不要になるか】
// 注意: KVC で engine を先に生成すると didInitializeImplicitFlutterEngine より前に
// Dart が動く場合がある。プラグインは AppDelegate 側の GeneratedPluginRegistrant
// のみで登録し、Dart 側は AppStorage.ensureReady() で登録完了を待つ。
// （Debug ビルドのデバッガ非接続起動は Flutter の仕様上、引き続き非推奨の可能性あり）
//
// 【削除手順（修正確認後）】
// 1. iPhone ProMotion + iOS 26 実機で Debug ビルドをホーム画面から起動しクラッシュしないことを確認
// 2. AppDelegate.swift から FlowDoPrewarmLaunchEngine 呼び出しを削除
// 3. Main.storyboard の customClass を FlutterViewController に戻す
// 4. 本ファイル・FlowDoLaunchPrewarm.m・FlowDoFlutterViewController.* を削除
// 5. Runner-Bridging-Header.h / project.pbxproj から参照を削除
//
// 関連ファイル: FlowDoLaunchPrewarm.m, FlowDoFlutterViewController.*

/// Storyboard 上の FlutterViewController が awake する前に launch engine を生成する。
void FlowDoPrewarmLaunchEngine(FlutterAppDelegate *delegate);

/// prewarm 側で GeneratedPluginRegistrant 済みなら YES
BOOL FlowDoLaunchPluginsRegistered(void);

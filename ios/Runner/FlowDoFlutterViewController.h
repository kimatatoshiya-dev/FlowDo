#import <Flutter/Flutter.h>

// Flutter 公式修正待ちの起動ワークアラウンド用 VC。
// 詳細・削除手順は FlowDoLaunchPrewarm.h を参照。
//
// Main.storyboard の customClass が FlowDoFlutterViewController になっている。
// ワークアラウンド削除時は FlutterViewController に戻すこと。

@interface FlowDoFlutterViewController : FlutterViewController
@end

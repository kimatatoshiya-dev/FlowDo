#import "FlowDoFlutterViewController.h"
#import "FlowDoLaunchPrewarm.h"

// takeLaunchEngine は FlutterAppDelegate の内部 API のため performSelector で取得。
// 公式修正後は Storyboard を FlutterViewController に戻し、本ファイルごと削除する。
static FlutterEngine* FlowDoTakeLaunchEngine(FlutterAppDelegate* delegate) {
  if (![delegate respondsToSelector:@selector(takeLaunchEngine)]) {
    return nil;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  return [delegate performSelector:@selector(takeLaunchEngine)];
#pragma clang diagnostic pop
}

@implementation FlowDoFlutterViewController

- (instancetype)initWithCoder:(NSCoder*)coder {
  FlutterAppDelegate* appDelegate =
      (FlutterAppDelegate*)UIApplication.sharedApplication.delegate;
  FlowDoPrewarmLaunchEngine(appDelegate);

  FlutterEngine* engine = FlowDoTakeLaunchEngine(appDelegate);
  if (engine != nil) {
    // initWithEngine で Engine を VC に明示的に結びつけ、viewDidLoad 前に shell を用意する。
    return [self initWithEngine:engine nibName:nil bundle:nil];
  }

  // フォールバック: 将来の Flutter テンプレート互換のため残す。
  return [super initWithCoder:coder];
}

@end

#import "FlowDoLaunchPrewarm.h"
#import "GeneratedPluginRegistrant.h"

// FlutterLaunchEngine は takeEngine 時に内部 _engine が未生成だと nil を返す。
// その状態で Storyboard FVC の viewDidLoad が走ると ProMotion 端末で VSyncClient が
// null task runner を参照して落ちる（flutter#153971）。
// 公開 API がないため KVC / performSelector で事前生成する。
//
// KVC で engine を先に生成すると didInitializeImplicitFlutterEngine より前に
// Dart が動きうる。SharedPreferences 等のプラグインをここで一度だけ登録し、
// AppDelegate 側では二重登録を避ける。
static BOOL _flowDoLaunchPluginsRegistered = NO;

BOOL FlowDoLaunchPluginsRegistered(void) {
  return _flowDoLaunchPluginsRegistered;
}

void FlowDoPrewarmLaunchEngine(FlutterAppDelegate *delegate) {
  id launchEngine = [delegate valueForKey:@"launchEngine"];
  if (launchEngine == nil) {
    return;
  }

  FlutterEngine *engine = nil;
  if ([launchEngine respondsToSelector:@selector(engine)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    engine = [launchEngine performSelector:@selector(engine)];
#pragma clang diagnostic pop
  }

  if (engine != nil && !_flowDoLaunchPluginsRegistered) {
    [GeneratedPluginRegistrant registerWithRegistry:engine];
    _flowDoLaunchPluginsRegistered = YES;
  }
}

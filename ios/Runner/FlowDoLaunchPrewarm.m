#import "FlowDoLaunchPrewarm.h"

// FlutterLaunchEngine は takeEngine 時に内部 _engine が未生成だと nil を返す。
// その状態で Storyboard FVC の viewDidLoad が走ると ProMotion 端末で VSyncClient が
// null task runner を参照して落ちる（flutter#153971）。
void FlowDoPrewarmLaunchEngine(FlutterAppDelegate *delegate) {
  id launchEngine = [delegate valueForKey:@"launchEngine"];
  if (launchEngine == nil) {
    return;
  }

  if ([launchEngine respondsToSelector:@selector(engine)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    (void)[launchEngine performSelector:@selector(engine)];
#pragma clang diagnostic pop
  }
}

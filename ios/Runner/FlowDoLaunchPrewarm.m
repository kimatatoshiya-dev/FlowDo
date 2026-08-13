#import "FlowDoLaunchPrewarm.h"

@interface FlutterEngine (FlowDoImplicitEngine)
- (BOOL)performImplicitEngineCallback;
@end

static FlutterEngine* FlowDoLaunchEngineInstance(FlutterAppDelegate* delegate) {
  id launchEngine = [delegate valueForKey:@"launchEngine"];
  if (launchEngine == nil) {
    return nil;
  }

  if ([launchEngine respondsToSelector:@selector(engine)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [launchEngine performSelector:@selector(engine)];
#pragma clang diagnostic pop
  }
  return nil;
}

// FlutterLaunchEngine は takeEngine 時に内部 _engine が未生成だと nil を返す。
// その状態で Storyboard FVC の viewDidLoad が走ると ProMotion 端末で VSyncClient が
// null task runner を参照して落ちる（flutter#153971）。
void FlowDoPrewarmLaunchEngine(FlutterAppDelegate* delegate) {
  (void)FlowDoLaunchEngineInstance(delegate);
}

void FlowDoRegisterImplicitPluginsOnce(FlutterAppDelegate* delegate) {
  static BOOL didRegisterPlugins = NO;
  if (didRegisterPlugins) {
    return;
  }

  FlutterEngine* engine = FlowDoLaunchEngineInstance(delegate);
  if (engine == nil) {
    return;
  }

  if ([engine performImplicitEngineCallback]) {
    didRegisterPlugins = YES;
  }
}

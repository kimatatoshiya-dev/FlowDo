#import "FlowDoFlutterViewController.h"
#import "FlowDoLaunchPrewarm.h"

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
    (void)[engine run];
    return [self initWithEngine:engine nibName:nil bundle:nil];
  }

  return [super initWithCoder:coder];
}

@end

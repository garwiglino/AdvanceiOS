// SPDX-License-Identifier: MPL-2.0
#import <UIKit/UIKit.h>
#import "MGBAPlayerViewController.h"

@interface MGBASceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation MGBASceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.tintColor = [UIColor colorWithRed:0.22 green:0.68 blue:0.50 alpha:1];
    self.window.rootViewController = [[MGBAPlayerViewController alloc] init];
    [self.window makeKeyAndVisible];
}
@end

@interface MGBAAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation MGBAAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions { return YES; }
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:connectingSceneSession.role];
    config.delegateClass = MGBASceneDelegate.class;
    return config;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(MGBAAppDelegate.class)); }
}

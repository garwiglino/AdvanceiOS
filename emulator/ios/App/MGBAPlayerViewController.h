// SPDX-License-Identifier: MPL-2.0
#import <UIKit/UIKit.h>
#import "MGBALibrary.h"
@interface MGBAPlayerViewController : UIViewController
- (instancetype)init; // Console shell opens its launcher inside the 240x160 screen.
- (instancetype)initWithGame:(MGBAGame *)game;
@end

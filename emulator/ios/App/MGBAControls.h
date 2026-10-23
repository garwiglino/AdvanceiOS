// SPDX-License-Identifier: MPL-2.0
#import <UIKit/UIKit.h>
@interface MGBAControls : UIView
@property (nonatomic, copy) void (^onKeys)(uint32_t keys);
// Geometry in view points, supplied by the SwiftUI facade. Artwork and hit targets
// are independent; this transparent view owns raw, simultaneous touch contacts.
- (void)configureVisualRegions:(NSDictionary<NSString *, NSValue *> *)visual
                   hitRegions:(NSDictionary<NSString *, NSValue *> *)hit;
- (void)releaseAll;
@end

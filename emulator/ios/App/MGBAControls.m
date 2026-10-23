// SPDX-License-Identifier: MPL-2.0
#import "MGBAControls.h"
#import "MGBASession.h"
#import "MGBAInput.h"
@implementation MGBAControls {
    NSMutableDictionary<NSValue *, NSNumber *> *_touchKeys;
    NSMutableSet<NSValue *> *_dpadTouches;
    NSDictionary<NSString *, NSValue *> *_visual, *_hit;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        _touchKeys = [NSMutableDictionary dictionary];
        _dpadTouches = [NSMutableSet set];
        self.accessibilityElementsHidden = YES; // SwiftUI supplies labelled controls.
    }
    return self;
}
- (void)configureVisualRegions:(NSDictionary<NSString *, NSValue *> *)visual hitRegions:(NSDictionary<NSString *, NSValue *> *)hit {
    if ([_visual isEqual:visual] && [_hit isEqual:hit]) return;
    [self releaseAll];
    _visual = [visual copy]; _hit = [hit copy];
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (NSValue *value in _hit.allValues) if (CGRectContainsPoint(value.CGRectValue, point)) return YES;
    return NO; // Screen taps and the pause control remain reachable.
}
- (NSString *)controlAtPoint:(CGPoint)point {
    NSString *closest = nil;
    CGFloat distance = CGFLOAT_MAX;
    for (NSString *name in _hit) {
        if (!CGRectContainsPoint(_hit[name].CGRectValue, point)) continue;
        CGRect r = _visual[name].CGRectValue;
        CGFloat dx = (point.x-CGRectGetMidX(r))/MAX(1,r.size.width);
        CGFloat dy = (point.y-CGRectGetMidY(r))/MAX(1,r.size.height);
        CGFloat d = dx*dx+dy*dy;
        if (d < distance) { distance = d; closest = name; }
    }
    return closest;
}
- (void)updateTouches:(NSSet<UITouch *> *)touches ended:(BOOL)ended {
    NSDictionary *mapping = @{@"a":@(MGBAKeyA), @"b":@(MGBAKeyB), @"l":@(MGBAKeyL), @"r":@(MGBAKeyR), @"start":@(MGBAKeyStart), @"select":@(MGBAKeySelect)};
    for (UITouch *touch in touches) {
        NSValue *identifier = [NSValue valueWithNonretainedObject:touch];
        if (ended) { [_touchKeys removeObjectForKey:identifier]; [_dpadTouches removeObject:identifier]; continue; }
        CGPoint point = [touch locationInView:self];
        NSString *name = [self controlAtPoint:point];
        if (touch.phase == UITouchPhaseBegan && [name isEqual:@"dpad"]) [_dpadTouches addObject:identifier];
        uint32_t keys = 0;
        if ([_dpadTouches containsObject:identifier]) {
            CGRect r = _visual[@"dpad"].CGRectValue;
            // Capture slides around the pivot, but release outside the local pad area.
            if (CGRectContainsPoint(CGRectInset(_hit[@"dpad"].CGRectValue,-16,-16),point))
                keys = MGBADirectionForPoint((point.x-CGRectGetMidX(r))/MAX(1,r.size.width/2), (point.y-CGRectGetMidY(r))/MAX(1,r.size.height/2));
        } else if (name) keys = [mapping[name] unsignedIntValue];
        _touchKeys[identifier] = @(keys);
    }
    uint32_t keys = 0;
    for (NSNumber *value in _touchKeys.allValues) keys |= value.unsignedIntValue;
    if (self.onKeys) self.onKeys(MGBACancelOpposingDirections(keys));
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:NO]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:NO]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:YES]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:YES]; }
- (void)releaseAll {
    [_touchKeys removeAllObjects]; [_dpadTouches removeAllObjects];
    if (self.onKeys) self.onKeys(0);
}
@end

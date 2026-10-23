// SPDX-License-Identifier: MPL-2.0
#import "MGBAControls.h"
#import "MGBASession.h"
#import "MGBAInput.h"
@implementation MGBAControls {
    NSMutableDictionary<NSValue *, NSNumber *> *_touchKeys;
    NSMutableDictionary<NSValue *, NSString *> *_owners;
    NSValue *_padTouch;
    CGPoint _padOrigin, _padPoint;
    NSDictionary<NSString *, NSValue *> *_visual, *_hit;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        _touchKeys = [NSMutableDictionary dictionary];
        _owners = [NSMutableDictionary dictionary];
        self.accessibilityElementsHidden = YES;
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
    return NO;
}
- (NSString *)controlAtPoint:(CGPoint)point {
    // Explicit controls take priority over the broad floating-pad activation area.
    for (NSString *name in @[@"a", @"b", @"l", @"r", @"select", @"start"])
        if (_hit[name] && CGRectContainsPoint(_hit[name].CGRectValue, point)) return name;
    if (_hit[@"dpad"] && CGRectContainsPoint(_hit[@"dpad"].CGRectValue, point)) return @"dpad";
    return nil;
}
- (void)updateTouches:(NSSet<UITouch *> *)touches ended:(BOOL)ended {
    NSDictionary *mapping = @{@"a":@(MGBAKeyA), @"b":@(MGBAKeyB), @"l":@(MGBAKeyL), @"r":@(MGBAKeyR), @"start":@(MGBAKeyStart), @"select":@(MGBAKeySelect)};
    for (UITouch *touch in touches) {
        NSValue *identifier = [NSValue valueWithNonretainedObject:touch];
        if (ended) {
            [_touchKeys removeObjectForKey:identifier];
            [_owners removeObjectForKey:identifier];
            if ([_padTouch isEqual:identifier]) _padTouch = nil;
            continue;
        }
        CGPoint point = [touch locationInView:self];
        if (touch.phase == UITouchPhaseBegan) {
            NSString *name = [self controlAtPoint:point];
            if ([name isEqual:@"dpad"]) {
                // A second contact must not steal the first thumb's origin.
                if (_padTouch) continue;
                _padTouch = identifier;
                _padOrigin = point;
                _padPoint = point;
            }
            if (name) _owners[identifier] = name;
        }
        NSString *owner = _owners[identifier];
        if (!owner) continue;
        uint32_t keys = 0;
        if ([owner isEqual:@"dpad"]) {
            _padPoint = point;
            CGFloat radius = MAX(1, _visual[@"dpad"].CGRectValue.size.width * 44.0/128.0);
            // The pivot stays exactly at initial contact, even near an edge.
            // Direction is retained outside the activation zone until touch-up.
            keys = MGBADirectionForPoint((point.x-_padOrigin.x)/radius, (point.y-_padOrigin.y)/radius);
        } else if (CGRectContainsPoint(_hit[owner].CGRectValue,point)) {
            keys = [mapping[owner] unsignedIntValue];
        }
        _touchKeys[identifier] = @(keys);
    }
    uint32_t keys = 0;
    for (NSNumber *value in _touchKeys.allValues) keys |= value.unsignedIntValue;
    if (self.onPad) self.onPad(_padOrigin, _padPoint, _padTouch != nil);
    if (self.onKeys) self.onKeys(MGBACancelOpposingDirections(keys));
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:NO]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:NO]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:YES]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateTouches:touches ended:YES]; }
- (void)releaseAll {
    [_touchKeys removeAllObjects]; [_owners removeAllObjects]; _padTouch = nil;
    if (self.onPad) self.onPad(CGPointZero, CGPointZero, NO);
    if (self.onKeys) self.onKeys(0);
}
@end

// SPDX-License-Identifier: MPL-2.0
#import "MGBASkin.h"
#include <math.h>
static BOOL ValidRect(id value) {
    if (![value isKindOfClass:NSArray.class] || [value count] != 4) return NO;
    for (id n in value) if (![n isKindOfClass:NSNumber.class] || !isfinite([n doubleValue])) return NO;
    NSArray *v = value;
    double x = [v[0] doubleValue], y = [v[1] doubleValue], w = [v[2] doubleValue], h = [v[3] doubleValue];
    return x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1.00001 && y + h <= 1.00001;
}
@implementation MGBASkin
+ (instancetype)skinForSize:(CGSize)size {
    if (size.width <= 0 || size.height <= 0) return nil;
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *root = [documents URLByAppendingPathComponent:@"Skins/default" isDirectory:YES];
    NSData *data = [NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"layout.json"]];
    if (!data) return nil;
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![decoded isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *manifest = decoded;
    if (![manifest[@"version"] isEqual:@1] || ![manifest[@"profiles"] isKindOfClass:NSArray.class]) return nil;
    CGFloat aspect = size.width / size.height;
    for (id entry in manifest[@"profiles"]) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *profile = entry;
        if (![profile[@"minAspect"] isKindOfClass:NSNumber.class] || ![profile[@"maxAspect"] isKindOfClass:NSNumber.class]) continue;
        if (aspect < [profile[@"minAspect"] doubleValue] || aspect >= [profile[@"maxAspect"] doubleValue]) continue;
        NSString *name = profile[@"image"];
        if (![name isKindOfClass:NSString.class] || ![name.lastPathComponent isEqual:name]) continue;
        NSDictionary *controls = profile[@"controls"];
        if (![controls isKindOfClass:NSDictionary.class] || !ValidRect(profile[@"screen"])) continue;
        BOOL valid = YES;
        for (NSString *key in @[@"a", @"b", @"l", @"r", @"start", @"select", @"dpad"])
            valid = valid && ValidRect(controls[key]);
        if (!valid) continue;
        UIImage *image = [UIImage imageWithContentsOfFile:[root URLByAppendingPathComponent:name].path];
        if (!image) continue;
        MGBASkin *skin = [MGBASkin new];
        skin.image = image;
        NSArray *s = profile[@"screen"];
        skin.normalizedScreen = CGRectMake([s[0] doubleValue], [s[1] doubleValue], [s[2] doubleValue], [s[3] doubleValue]);
        skin.controls = controls;
        NSMutableDictionary *buttonImages = [NSMutableDictionary dictionary];
        NSDictionary *images = profile[@"buttonImages"];
        if ([images isKindOfClass:NSDictionary.class]) {
            for (NSString *key in @[@"a", @"b", @"l", @"r", @"start", @"select", @"dpad"]) {
                NSDictionary *states = images[key];
                if (![states isKindOfClass:NSDictionary.class]) continue;
                NSMutableDictionary *loaded = [NSMutableDictionary dictionary];
                for (NSString *state in @[@"normal", @"pressed", @"up", @"down", @"left", @"right", @"upLeft", @"upRight", @"downLeft", @"downRight"]) {
                    NSString *asset = states[state];
                    if (![asset isKindOfClass:NSString.class] || ![asset.lastPathComponent isEqual:asset]) continue;
                    UIImage *buttonImage = [UIImage imageWithContentsOfFile:[root URLByAppendingPathComponent:asset].path];
                    if (buttonImage) loaded[state] = buttonImage;
                }
                if (loaded[@"normal"]) buttonImages[key] = loaded;
            }
        }
        skin.buttonImages = buttonImages;
        return skin;
    }
    return nil;
}
@end

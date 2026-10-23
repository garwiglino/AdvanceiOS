// SPDX-License-Identifier: MPL-2.0
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface MGBASkin : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic) CGRect normalizedScreen;
@property (nonatomic, copy) NSDictionary *controls;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, UIImage *> *> *buttonImages;
+ (nullable instancetype)skinForSize:(CGSize)size;
@end
NS_ASSUME_NONNULL_END

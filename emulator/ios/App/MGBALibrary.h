// SPDX-License-Identifier: MPL-2.0
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface MGBAGame : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSURL *romURL;
@property (nonatomic, strong) NSURL *directory;
@end
@interface MGBALibrary : NSObject
- (NSArray<MGBAGame *> *)games;
- (nullable MGBAGame *)importROM:(NSURL *)url error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END

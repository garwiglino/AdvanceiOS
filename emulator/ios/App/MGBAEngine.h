// SPDX-License-Identifier: MPL-2.0
#import <UIKit/UIKit.h>
#import "MGBASession.h"
NS_ASSUME_NONNULL_BEGIN
@interface MGBAEngine : NSObject
@property (nonatomic, readonly) BOOL running;
@property (nonatomic) uint32_t keys;
@property (nonatomic) BOOL fastForward;
@property (nonatomic, copy, nullable) void (^onFrame)(UIImage *image);
@property (nonatomic, copy, nullable) void (^onError)(NSError *error);
- (void)loadROM:(NSURL *)rom directory:(NSURL *)directory completion:(void (^)(NSError * _Nullable))completion;
- (BOOL)resume:(NSError **)error;
// Synchronously drains the emulation queue and persists battery + resume state.
- (nullable NSError *)pauseAndSave;
- (void)close;
- (void)saveSlot:(NSInteger)slot completion:(void (^)(NSError * _Nullable))completion;
- (void)loadSlot:(NSInteger)slot completion:(void (^)(NSError * _Nullable))completion;
- (void)reset;
@end
NS_ASSUME_NONNULL_END

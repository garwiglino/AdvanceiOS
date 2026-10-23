// SPDX-License-Identifier: MPL-2.0
#import "MGBALibrary.h"
#import "MGBASession.h"
#import <CommonCrypto/CommonDigest.h>
@implementation MGBAGame
@end
@implementation MGBALibrary
- (NSURL *)root {
    return [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"Games" isDirectory:YES];
}
- (NSArray<MGBAGame *> *)games {
    NSMutableArray *games = [NSMutableArray array];
    NSArray *directories = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.root includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *directory in directories) {
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfURL:[directory URLByAppendingPathComponent:@"game.plist"]];
        NSString *filename = metadata[@"filename"], *title = metadata[@"title"];
        if (![filename isKindOfClass:NSString.class] || ![title isKindOfClass:NSString.class] || ![filename.lastPathComponent isEqualToString:filename]) continue;
        NSURL *rom = [directory URLByAppendingPathComponent:filename];
        if (![NSFileManager.defaultManager fileExistsAtPath:rom.path]) continue;
        MGBAGame *game = [MGBAGame new];
        game.title = title;
        game.directory = directory;
        game.romURL = rom;
        [games addObject:game];
    }
    return [games sortedArrayUsingComparator:^NSComparisonResult(MGBAGame *a, MGBAGame *b) { return [a.title localizedStandardCompare:b.title]; }];
}
- (MGBAGame *)importROM:(NSURL *)url error:(NSError **)error {
    NSString *ext = url.pathExtension.lowercaseString;
    if (![@[@"gba", @"gb", @"gbc"] containsObject:ext]) {
        if (error) *error = [NSError errorWithDomain:@"mGBA.iOS" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Choisissez un fichier .gba, .gb ou .gbc décompressé."}];
        return nil;
    }
    BOOL scoped = [url startAccessingSecurityScopedResource];
    __block NSData *data;
    __block NSError *readError = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&readError byAccessor:^(NSURL *newURL) {
        NSNumber *size = nil;
        [newURL getResourceValue:&size forKey:NSURLFileSizeKey error:&readError];
        if (readError) return;
        if (size.unsignedLongLongValue > 32 * 1024 * 1024) {
            readError = [NSError errorWithDomain:@"mGBA.iOS" code:3 userInfo:@{NSLocalizedDescriptionKey:@"La ROM dépasse 32 Mo."}];
            return;
        }
        data = [NSData dataWithContentsOfURL:newURL options:0 error:&readError];
    }];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data || readError) { if (error) *error = readError; return nil; }
    MGBASession *validation = MGBACreate(data.bytes, data.length, NULL, 0);
    if (!validation) {
        if (error) *error = [NSError errorWithDomain:@"mGBA.iOS" code:4 userInfo:@{NSLocalizedDescriptionKey:@"mGBA ne reconnaît pas ce fichier comme un jeu GBA, GB ou GBC."}];
        return nil;
    }
    MGBADestroy(validation);
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *identifier = [NSMutableString string];
    for (unsigned i = 0; i < sizeof(digest); ++i) [identifier appendFormat:@"%02x", digest[i]];
    NSURL *directory = [self.root URLByAppendingPathComponent:identifier isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSString *filename = [@"game" stringByAppendingPathExtension:ext];
    NSURL *rom = [directory URLByAppendingPathComponent:filename];
    if (![data writeToURL:rom options:NSDataWritingAtomic error:error]) return nil;
    NSDictionary *metadata = @{@"title":url.lastPathComponent.stringByDeletingPathExtension, @"filename":filename};
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:metadata format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (!plist || ![plist writeToURL:[directory URLByAppendingPathComponent:@"game.plist"] options:NSDataWritingAtomic error:error]) return nil;
    MGBAGame *game = [MGBAGame new];
    game.title = metadata[@"title"];
    game.romURL = rom;
    game.directory = directory;
    return game;
}
@end

//
// Created by vhbit on 3/6/13.
//

#import <zlib.h>
#import "ZZArchive+ZZExtraction.h"
#import "ZZArchiveEntry.h"
#import "NSOutputStream+ZZExtraction.h"

NSString *const ZZCorruptedFilesKey = @"ZZCorruptedFiles";
NSString *const ZZInvalidDestinationsKey = @"ZZInvalidDestinations";

@implementation ZZExtractionBlockBasedDelegate
- (NSString *)archive:(ZZArchive *)archive renameFile:(NSString *)fileName
{
    if (_renamerBlock)
        return _renamerBlock(fileName);

    return fileName;
}

- (BOOL)archive:(ZZArchive *)archive shouldOverwriteFile:(NSString *)fileName
{
    if (_shouldOverwriteBlock)
        return _shouldOverwriteBlock(fileName);

    return NO;
}

- (BOOL)archive:(ZZArchive *)archive shouldCheckFileIntegrity:(NSString *)fileName
{
    if (_shouldCheckIntegrityBlock)
        return _shouldCheckIntegrityBlock(fileName);

    return NO;
}

- (void)archive:(ZZArchive *)archive gotCorruptedFile:(NSString *)fileName
{
    if (_gotCorruptedFileBlock)
        _gotCorruptedFileBlock(fileName);
}

- (void)archive:(ZZArchive *)archive gotInvalidDestinationPath:(NSString *)path
{
    if (_invalidDestinationBlock)
        _invalidDestinationBlock(path);
}

@end

@implementation ZZArchive (ZZExtraction)

+ (ZZFileNameProcessor)preservingFileNameProcessor:(NSString *)destinationPath
{
    return ^(NSString *fileName) {
        NSArray *pathComponents = [fileName pathComponents];

        NSString *relativePath = @"";
        if (pathComponents.count > 1)
            relativePath = [[pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 1)] componentsJoinedByString:@"/"];

        NSString *justName = [pathComponents lastObject];
        NSString *destDir = [destinationPath stringByAppendingPathComponent:relativePath];
        return [destDir stringByAppendingPathComponent:justName];
    };
}

+ (ZZFileNameProcessor)nonPreservingFileNameProcessor:(NSString *)destinationPath
{
    return ^(NSString *fileName) {
        return [destinationPath stringByAppendingPathComponent:[fileName lastPathComponent]];
    };
}

+ (BOOL)ensureDirExists:(NSString *)dir
{
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir];
    if (!exists)
        return [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:nil];

    return isDir;
}

- (void)extractToPath:(NSString *)destinationPath
{
    [self extractToPath:destinationPath options:ZZExtractionOverwrite | ZZExtractionPreserveDirStructure error:nil];
}

- (void)extractToPath:(NSString *)destinationPath options:(ZZExtractionFlags)options error:(NSError **)error {
    ZZExtractionBlockBasedDelegate *tempDelegate = [[ZZExtractionBlockBasedDelegate alloc] init];

    NSMutableArray *corruptedFiles = [NSMutableArray array];
    NSMutableArray *invalidDestinations = [NSMutableArray array];

    if (options & ZZExtractionPreserveDirStructure)
        tempDelegate.renamerBlock = [[self class] preservingFileNameProcessor:destinationPath];
    else
        tempDelegate.renamerBlock = [[self class] nonPreservingFileNameProcessor:destinationPath];

    if (options & ZZExtractionOverwrite)
    {
        tempDelegate.shouldOverwriteBlock = ^(NSString *fileName) {
            return YES;
        };
    }

    if (options & ZZExtractionCheckCRC32)
    {
        tempDelegate.shouldCheckIntegrityBlock = ^(NSString *fileName) {
            return YES;
        };
        tempDelegate.gotCorruptedFileBlock = ^(NSString *fileName) {
            [corruptedFiles addObject:fileName];
        };
    }

    tempDelegate.invalidDestinationBlock = ^(NSString *fileName) {
        [invalidDestinations addObject:fileName];
    };

    [self extractToPath:destinationPath delegate:tempDelegate];

    if (error && (invalidDestinations.count > 0 || corruptedFiles.count > 0))
    {
        *error = [NSError errorWithDomain:@"ZZArchive"
                                     code:0
                                 userInfo:
                                         @{
                                                 NSLocalizedDescriptionKey: @"Got errors during extracting files",
                                                 ZZInvalidDestinationsKey : invalidDestinations,
                                                 ZZCorruptedFilesKey : corruptedFiles
                                         }];
    }
}

- (void)extractToPath:(NSString *)destinationPath delegate:(id<ZZExtractionDelegate>)delegate
{
    BOOL hasRenamer = delegate && [delegate respondsToSelector:@selector(archive:renameFile:)];
    BOOL hasOverwriteHandler = delegate && [delegate respondsToSelector:@selector(archive:shouldOverwriteFile:)];
    BOOL hasIntegrityChecker = delegate && [delegate respondsToSelector:@selector(archive:shouldCheckFileIntegrity:)];
    BOOL hasCorruptionHandler = delegate && [delegate respondsToSelector:@selector(archive:gotCorruptedFile:)];
    BOOL hasInvalidPathHandler = delegate && [delegate respondsToSelector:@selector(archive:gotInvalidDestinationPath:)];

    for (ZZArchiveEntry *entry in self.entries)
    {
        NSString *outPath = hasRenamer ? [delegate archive:self renameFile:entry.fileName] : [destinationPath stringByAppendingPathComponent:entry.fileName];
        if (entry.fileMode & S_IFDIR)
        {
            if (![[self class] ensureDirExists:outPath])
            {
                if (hasInvalidPathHandler)
                    [delegate archive:self gotInvalidDestinationPath:outPath];
            }
        }
        else
        {
            NSString *outDir = [outPath stringByDeletingLastPathComponent];

            if (![[self class] ensureDirExists:outDir])
            {
                if (hasInvalidPathHandler)
                    [delegate archive:self gotInvalidDestinationPath:outDir];
            }
            else
            {
                NSInputStream *inStream = entry.stream;
                [inStream open];

                if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath] && (hasOverwriteHandler && ![delegate archive:self shouldOverwriteFile:entry.fileName]))
                {
                    // TODO: combine to error log
                }
                else
                {
                    NSOutputStream *outStream = [NSOutputStream outputStreamToFileAtPath:outPath append:NO];
                    [outStream open];

                    if (!hasIntegrityChecker || ![delegate archive:self shouldCheckFileIntegrity:entry.fileName])
                        [outStream ZZ_copyFromStream:inStream bufferSize:1024*128];
                    else
                    {
                        uLong __block crc32Digest = crc32(0L, Z_NULL, 0);
                        [outStream ZZ_copyFromStream:inStream
                                          bufferSize:1024 * 128
                                       dataProcessor:^(uint8_t *buffer, NSUInteger length) {
                                           crc32Digest = crc32(crc32Digest, buffer, (uint)length);
                                       }];
                        [outStream close];

                        if (crc32Digest != entry.crc32 && hasCorruptionHandler)
                            [delegate archive:self gotCorruptedFile:entry.fileName];
                    }

                    if (outStream.streamStatus != NSStreamStatusClosed)
                        [outStream close];
                }
                [inStream close];
            }
        }
    }
}
@end
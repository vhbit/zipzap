//
// Created by vhbit on 3/6/13.
//

#import <Foundation/Foundation.h>
#import "ZZArchive.h"

extern NSString *const ZZInvalidDestinationsKey;
extern NSString *const ZZCorruptedFilesKey;

typedef NSString* (^ZZFileNameProcessor)(NSString *fileName);

typedef enum {
    ZZExtractionOverwrite = 1,
    ZZExtractionPreserveDirStructure = 1 << 1,
    ZZExtractionCheckCRC32 = 1 << 2
} ZZExtractionFlag;

typedef NSUInteger ZZExtractionFlags;


@protocol ZZExtractionDelegate<NSObject>
@optional

/* Gets a entry fileName and should provide full path for extracting */
- (NSString *)archive:(ZZArchive *)archive renameFile:(NSString *)fileName;

/* By default overwriting is prohibited */
- (BOOL)archive:(ZZArchive *)archive shouldOverwriteFile:(NSString *)fileName;

/* By default no CRC checking will be performed */
- (BOOL)archive:(ZZArchive *)archive shouldCheckFileIntegrity:(NSString *)fileName;

- (void)archive:(ZZArchive *)archive gotCorruptedFile:(NSString *)fileName;

/* Triggers when the destination path is unavailable: for example if
 * path doesn't exist and can't be created or if it exists and is
 * a regular file */
- (void)archive:(ZZArchive *)archive gotInvalidDestinationPath:(NSString *)path;

/* TODO: additional checks for available space and stream errors */
@end

@interface ZZArchive (ZZExtraction)

/* Actually those ones are supposed to be private, but have been
extracted for testing purposes */
+ (ZZFileNameProcessor)preservingFileNameProcessor:(NSString *)destinationPath;
+ (ZZFileNameProcessor)nonPreservingFileNameProcessor:(NSString *)destinationPath;

/* Default options: No integrity check, overwrite, preserve structure */
- (void)extractToPath:(NSString *)destinationPath;

/*
 error user info contains information in the following keys:
 ZZInvalidDestinationsKey
 ZZCorruptedFilesKey
 */
- (void)extractToPath:(NSString *)destinationPath options:(ZZExtractionFlags)options error:(NSError **)error;

/* Everything is configurable through delegate */
- (void)extractToPath:(NSString *)destinationPath delegate:(id<ZZExtractionDelegate>)delegate;
@end

/* Convenient block-based delegate */
@interface ZZExtractionBlockBasedDelegate: NSObject<ZZExtractionDelegate>
@property(nonatomic, copy) ZZFileNameProcessor renamerBlock;
@property(nonatomic, copy) BOOL (^shouldOverwriteBlock)(NSString *);
@property(nonatomic, copy) BOOL (^shouldCheckIntegrityBlock)(NSString *);
@property(nonatomic, copy) void (^gotCorruptedFileBlock)(NSString *);
@property(nonatomic, copy) void (^invalidDestinationBlock)(NSString *);
@end

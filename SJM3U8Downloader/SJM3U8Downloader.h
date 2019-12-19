//
//  SJM3U8Downloader.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SJM3U8TSDownloadOperationQueue.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8Downloader : NSObject
+ (instancetype)shared;
- (instancetype)initWithRootFolder:(NSString *)path;
- (instancetype)initWithRootFolder:(NSString *)path port:(UInt16)port;

- (nullable SJM3U8TSDownloadOperationQueue *)download:(NSString *)url;
- (nullable SJM3U8TSDownloadOperationQueue *)download:(NSString *)url folderName:(nullable NSString *)name;

- (void)deleteWithUrl:(NSString *)url;
- (void)deleteWithFolderName:(NSString *)name;

- (NSString *)localPlayUrlByUrl:(NSString *)url;
- (NSString *)localPlayUrlByFolderName:(NSString *)name;
@end
NS_ASSUME_NONNULL_END

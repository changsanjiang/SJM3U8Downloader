//
//  SJM3U8TSDownloadOperation.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/17.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8TSDownloadOperation : NSOperation
- (instancetype)initWithURL:(NSString *)tsurl toPath:(NSString *)path;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, copy, readonly) NSString *path;

///
/// Will be executed on the main thread
///
@property (nonatomic, copy, nullable) void(^downalodCompletionHandler)(SJM3U8TSDownloadOperation *operation, NSError *_Nullable error);

@property (nonatomic, readonly, getter=isDownloadFininished) BOOL downloadFinished;
@property (nonatomic, readonly) float downloadProgress;
@property (nonatomic, readonly) int64_t totalSize;
@property (nonatomic, readonly) int64_t wroteSize;

- (void)suspend;
- (void)resume;
- (void)cancelOperation;

- (void)finishedOperation;
@end
NS_ASSUME_NONNULL_END

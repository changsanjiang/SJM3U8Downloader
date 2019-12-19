//
//  SJM3U8DownloadListOperation.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/18.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SJM3U8DownloadListControllerDefines.h"
#import "SJM3U8Downloader.h"
@protocol SJM3U8DownloadListOperationDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8DownloadListOperation : NSOperation
- (instancetype)initWithUrl:(NSString *)url folderName:(nullable NSString *)folderName downloader:(SJM3U8Downloader *)downloader delegate:(id<SJM3U8DownloadListOperationDelegate>)delegate;
@property (nonatomic, weak, nullable) id<SJM3U8DownloadListOperationDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, copy, readonly, nullable) NSString *folderName;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) int64_t speed;
@property (nonatomic, readonly) NSTimeInterval periodicTimeInterval;

- (void)finishedOperation;
- (void)cancelOperation;
@end

@protocol SJM3U8DownloadListOperationDelegate <NSObject>
- (void)operationDidStart:(SJM3U8DownloadListOperation *)operation;
- (void)operation:(SJM3U8DownloadListOperation *)operation didComplete:(BOOL)isFinished;
- (void)progressDidChangeForOperation:(SJM3U8DownloadListOperation *)operation;
@end
NS_ASSUME_NONNULL_END

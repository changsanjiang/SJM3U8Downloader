//
//  SJM3U8TSDownloadOperationQueue.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
extern NSNotificationName const SJM3U8TSDownloadOperationQueueStateDidChangeNotification;
extern NSNotificationName const SJM3U8TSDownloadOperationQueueProgressDidChangeNotification;

typedef enum : NSUInteger {
    SJDownloadTaskStateSuspended,
    SJDownloadTaskStateRunning,
    SJDownloadTaskStateCancelled,
    SJDownloadTaskStateFinished,
    SJDownloadTaskStateFailed,
} SJDownloadTaskState;

@interface SJM3U8TSDownloadOperationQueue : NSObject
- (instancetype)initWithUrl:(NSString *)m3u8url saveToFolder:(NSString *)folder;

///
/// errorCode:
///     3000    解析m3u8文件失败
///     3001    文件保存失败
///     3002    下载ts失败
///
///
@property (nonatomic, readonly) NSInteger errorCode;
@property (nonatomic, readonly) SJDownloadTaskState state;
@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) int64_t speed; ///< bytes


@property (nonatomic) NSTimeInterval periodicTimeInterval; ///< default value is 0.5
@property (nonatomic, copy, nullable) void(^progressDidChangeExeBlock)(SJM3U8TSDownloadOperationQueue *queue);
@property (nonatomic, copy, nullable) void(^stateDidChangeExeBlock)(SJM3U8TSDownloadOperationQueue *queue);

- (void)resume;
- (void)suspend;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END

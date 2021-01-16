//
//  SJM3U8TSDownloadOperation.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/17.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8TSDownloadOperation.h"
#import <SJDownloadDataTask/SJDownloadDataTask.h>
#import "SJM3U8Configuration.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8TSDownloadOperation () {
    BOOL _isCancelled;
}
@property (nonatomic, getter=isDownloadFininished) BOOL downloadFinished;
@property (nonatomic, getter=isExecuting) BOOL executing;
@property (nonatomic, getter=isFinished) BOOL finished;
@property (nonatomic, strong, nullable) SJDownloadDataTask *downloadTask;
@end

@implementation SJM3U8TSDownloadOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithURL:(NSString *)url toPath:(NSString *)path {
    self = [super init];
    if ( self ) {
        _url = url;
        _path = path;
    }
    return self;
}

#ifdef SJDEBUG
- (void)dealloc {
    NSLog(@"%d \t %s", (int)__LINE__, __func__);
}
#endif

- (BOOL)isAsynchronous {
    return YES;
}

- (void)setExecuting:(BOOL)executing {
    if ( executing == _executing ) return;
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished {
    if ( finished == _finished ) return;
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)start {
    @synchronized (self) {
        
        if ( _isCancelled ) {
            self.finished = YES;
            return;
        }
        
        self.executing = YES;
        __weak typeof(self) _self = self;
        __auto_type completionHandler = ^(SJDownloadDataTask * _Nonnull dataTask) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(_self) self = _self;
                if ( !self ) return;
                if ( dataTask.error.code == NSURLErrorTimedOut ) {
                    [dataTask restart];
                    return;
                }
                
                self.downloadFinished = dataTask.error == nil;
                if ( self.downalodCompletionHandler != nil ) self.downalodCompletionHandler(self, dataTask.error);
            });
        };
        
        _downloadTask = [SJDownloadDataTask downloadWithURLStr:self.url toPath:[NSURL fileURLWithPath:self.path] append:YES response:^BOOL(SJDownloadDataTask * _Nonnull dataTask, NSURLResponse *response) {
            __strong typeof(_self) self = _self;
            if ( !self ) return NO;
            BOOL allows = [response.MIMEType hasPrefix:@"video"] ||
                          [response.MIMEType hasPrefix:@"application/octet-stream"];
            
            if ( SJM3U8Configuration.shared.allowDownloads != nil ) {
                allows = SJM3U8Configuration.shared.allowDownloads(response);
            }
            
            if ( allows )
                return YES;

            if ( self.downalodCompletionHandler != nil ) {
#ifdef DEBUG
                NSLog(@"格式异常, 无法继续下载");
#endif
                self.downalodCompletionHandler(self, [NSError errorWithDomain:NSCocoaErrorDomain code:3002 userInfo:@{@"msg":@"格式异常, 无法继续下载"}]);
            }
            return NO;
        } progress:nil success:completionHandler failure:completionHandler];
    }
}

- (float)downloadProgress {
    @synchronized (self) {
        if ( _downloadTask.totalSize == NSURLSessionTransferSizeUnknown )
            return 0;
        return _downloadTask.progress;
    }
}

- (int64_t)wroteSize {
    @synchronized (self) {
        if ( _downloadTask.totalSize == NSURLSessionTransferSizeUnknown )
            return 0;
        return _downloadTask.wroteSize;
    }
}

- (int64_t)totalSize {
    @synchronized (self) {
        if ( _downloadTask.totalSize == NSURLSessionTransferSizeUnknown )
            return 0;
        return _downloadTask.totalSize;
    }
}

- (void)suspend {
    @synchronized (self) {
        if ( self.finished )
            return;
        [_downloadTask cancel];
    }
}

- (void)resume {
    @synchronized (self) {
        if ( self.finished )
            return;
        [_downloadTask restart];
    }
}

- (void)cancelOperation {
    @synchronized (self) {
        _isCancelled = YES;
        
        [_downloadTask cancel];
        _downloadTask = nil;
        
        if ( self.executing == YES ) {
            [self finishedOperation];
        }
    }
}

- (void)finishedOperation {
    @synchronized (self) {
        self.executing = NO;
        self.finished = YES;
    }
}
@end
NS_ASSUME_NONNULL_END

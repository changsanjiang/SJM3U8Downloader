//
//  SJM3U8DownloadListOperation.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/18.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8DownloadListOperation.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8DownloadListOperation () {
    BOOL _isCancelled;
}
@property (nonatomic, strong, readonly) SJM3U8Downloader *downloader;
@property (nonatomic, strong, nullable) SJM3U8TSDownloadOperationQueue *queue;
@property (nonatomic, getter=isExecuting) BOOL executing;
@property (nonatomic, getter=isFinished) BOOL finished;
@end
@implementation SJM3U8DownloadListOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithUrl:(NSString *)url folderName:(nullable NSString *)folderName downloader:(SJM3U8Downloader *)downloader delegate:(id<SJM3U8DownloadListOperationDelegate>)delegate {
    self = [super init];
    if ( self ){
        _url = url;
        _folderName = folderName;
        _downloader = downloader;
        _delegate = delegate;
    }
    return self;
}

- (float)progress {
    @synchronized (self) {
        return _queue.progress;
    }
}

- (int64_t)speed {
    @synchronized (self) {
        return _queue.speed;
    }
}

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

#pragma mark -
- (void)start {
    @synchronized (self) {
        if ( _isCancelled ) {
            self.finished = YES;
            return;
        }
        
        self.executing = YES;
        _queue = [self.downloader download:_url folderName:_folderName];
        __weak typeof(self) _self = self;
        _queue.progressDidChangeExeBlock = ^(SJM3U8TSDownloadOperationQueue * _Nonnull queue) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            [self _progressDidChange];
        };
        _queue.stateDidChangeExeBlock = ^(SJM3U8TSDownloadOperationQueue * _Nonnull queue) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            [self _stateDidChange:queue];
        };
        [_queue resume];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate operationDidStart:self];
        });
        
        [self _stateDidChange:_queue];
        [self _progressDidChange];
    }
}

- (NSTimeInterval)periodicTimeInterval {
    return 0.5;
}

- (void)cancelOperation {
    @synchronized (self) {
        _isCancelled = YES;
        [_queue suspend];
        
        if ( self.executing == YES ) {
            [self finishedOperation];
        }
    }
}

- (void)finishedOperation {
    @synchronized (self) {
        self.executing = NO;
        self.finished = YES;
        [_queue suspend];
    }
}

#pragma mark -

- (void)_stateDidChange:(SJM3U8TSDownloadOperationQueue *)queue {
    __weak typeof(self) _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( queue.state == SJDownloadTaskStateFailed ) {
            [self.delegate operation:self didComplete:NO];
        }
        else if ( queue.state == SJDownloadTaskStateFinished ) {
            [self.delegate operation:self didComplete:YES];
        }
    });
}

- (void)_progressDidChange {
    __weak typeof(self) _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.delegate progressDidChangeForOperation:self];
    });
}
@end
NS_ASSUME_NONNULL_END

//
//  SJM3U8Downloader.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8Downloader.h"
#import <sys/xattr.h>
#import <SJMediaCacheServer/HTTPServer.h>

NS_ASSUME_NONNULL_BEGIN
#define SJM3U8DownloaderFoldername(__url__) [NSString stringWithFormat:@"%lu", (unsigned long)__url__.hash]

@interface SJM3U8Downloader ()
@property (nonatomic, copy, readonly) NSString *rootFolder; ///< 存放文件的根目录
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, SJM3U8TSDownloadOperationQueue *> *queues;
@property (nonatomic, strong, readonly) HTTPServer *httpServer;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) UInt16 port;
@property (nonatomic, strong) NSURL *serverURL;
@end

@implementation SJM3U8Downloader {
    dispatch_semaphore_t _lock;
}
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = self.new;
    });
    return obj;
}

- (instancetype)initWithRootFolder:(NSString *)path {
    return [self initWithRootFolder:path port:12345];
}

- (instancetype)initWithRootFolder:(NSString *)path port:(UInt16)port {
    self = [super init];
    if ( self ) {
        _port = port;
        _lock = dispatch_semaphore_create(1);
        _queues = NSMutableDictionary.dictionary;
        _rootFolder = path;
        if ( ![NSFileManager.defaultManager fileExistsAtPath:path] ) {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            const char *filePath = [path fileSystemRepresentation];
            const char *attrName = "com.apple.MobileBackup";
            u_int8_t attrValue = 1;
            setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        }
        
        _backgroundTask = UIBackgroundTaskInvalid;
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];

        
        /// local server
        _httpServer = [HTTPServer new];
        [_httpServer setType:@"_http._tcp."];
        [_httpServer setPort:port];
        [_httpServer setDocumentRoot:path];
        [self start];
    }
    return self;
}

- (instancetype)init {
    return [self initWithRootFolder:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"sj.download.files"]];
}

- (nullable SJM3U8TSDownloadOperationQueue *)download:(NSString *)url {
    return [self download:url folderName:nil];
}

- (nullable SJM3U8TSDownloadOperationQueue *)download:(NSString *)url folderName:(nullable NSString *)name {
    if ( url.length == 0 ) return nil;
    if ( name == nil ) name = SJM3U8DownloaderFoldername(url);
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    SJM3U8TSDownloadOperationQueue *_Nullable queue = _queues[name];
    if ( queue == nil || queue.state == SJDownloadTaskStateCancelled ) {
        NSString *folder = [self.rootFolder stringByAppendingPathComponent:name];
        queue = [SJM3U8TSDownloadOperationQueue.alloc initWithUrl:url saveToFolder:folder];
        _queues[name] = queue;
    }
    dispatch_semaphore_signal(_lock);
    return queue;
}

- (void)deleteWithUrl:(NSString *)url {
    [self deleteWithFolderName:SJM3U8DownloaderFoldername(url)];
}

- (void)deleteWithFolderName:(NSString *)name {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    SJM3U8TSDownloadOperationQueue *_Nullable queue = _queues[name];
    if ( queue != nil ) {
        [_queues[name] cancel];
        _queues[name] = nil;
    }
    else {
        [NSFileManager.defaultManager removeItemAtPath:[self.rootFolder stringByAppendingPathComponent:name] error:NULL];
    }
    dispatch_semaphore_signal(_lock);
}

- (NSString *)localPlayUrlByUrl:(NSString *)url {
    return [self localPlayUrlByFolderName:SJM3U8DownloaderFoldername(url)];
}

- (NSString *)localPlayUrlByFolderName:(NSString *)name {
    return [NSString stringWithFormat:@"http://127.0.0.1:%d/%@/index.m3u8", _httpServer.port, name];
}

#pragma mark - mark

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isRunning {
    return _httpServer.isRunning;
}

- (void)start {
    if ( self.isRunning )
        return;
    
    for ( int i = 0 ; i < 10 ; ++ i ) {
        if ( [self _start:NULL] ) {
            _serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d", _port]];
            break;
        }
        [_httpServer setPort:_port += (UInt16)(arc4random() % 1000 + 1)];
    }
}

- (void)stop {
    [self _stop];
}

- (void)applicationDidEnterBackground {
    [self _beginBackgroundTask];
}

- (void)applicationWillEnterForeground {
    if ( self.backgroundTask == UIBackgroundTaskInvalid && !self.isRunning ) {
        [self _start:nil];
    }
    [self _endBackgroundTask];
}

#pragma mark -

- (BOOL)_start:(NSError **)error {
    return [_httpServer start:error];
}

- (void)_stop {
    [_httpServer stop];
}

- (void)_beginBackgroundTask {
    if ( self.backgroundTask == UIBackgroundTaskInvalid ) {
        self.backgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
            [self _stop];
            [self _endBackgroundTask];
        }];
    }
}

- (void)_endBackgroundTask {
    if ( self.backgroundTask != UIBackgroundTaskInvalid ) {
        [UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
NS_ASSUME_NONNULL_END

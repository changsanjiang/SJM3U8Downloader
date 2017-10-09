//
//  SJDownloadServer.m
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/5.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import "SJDownloadServer.h"
#import "SJTsEntity.h"
#import <objc/message.h>
#import <HTTPServer.h>

NSErrorDomain const SJDownloadErrorDomain = @"SJDownloadErrorDomain";

NSErrorUserInfoKey const SJDownloadErrorInfoKey = @"SJDownloadErrorInfoKey";

static int const SJDownloadCancelCode = -999;



typedef NS_ENUM(NSUInteger, SJDownloadState) {
    SJDownloadState_Unknown,
    
    /*!* 下载中 */
    SJDownloadState_Downloading,
    
    /*!* 已下载 */
    SJDownloadState_Downloaded,
    
    /*!* 暂停 */
    SJDownloadState_Suspend,
    
    /*!* 下载失败 */
    SJDownloadState_Failed,
};




inline static NSError *_downloadServerError(SJDownloadErrorCode code, NSString *errorMsg) {
    return [NSError errorWithDomain:SJDownloadErrorDomain code:code userInfo:@{SJDownloadErrorInfoKey:@"msg"}];
}

inline static NSString *_getModeStr(SJDownloadMode mode) {
    NSString *modeStr = nil;
    switch (mode) {
        case SJDownloadMode450: {
            modeStr = @"450.m3u8";
        }
            break;
        case SJDownloadMode200: {
            modeStr = @"200.m3u8";
        }
            break;
        case SJDownloadMode850: {
            modeStr = @"850.m3u8";
        }
            break;
    }
    return modeStr;
}

inline static NSURL *_getTssDownloadURLStr(NSString *URLStr, SJDownloadMode mode) {
    NSURLComponents *components = [NSURLComponents componentsWithString:URLStr];
    NSString *modeStr = _getModeStr(mode);
    NSString *path = [modeStr stringByDeletingPathExtension];
    NSMutableArray<NSString *> *pathComponentsM = components.path.pathComponents.mutableCopy;
    pathComponentsM[pathComponentsM.count - 1] = modeStr;
    [pathComponentsM enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( ![obj isEqualToString:@"hls"] ) return;
        *stop = YES;
        pathComponentsM[idx + 1] = path;
    }];
    components.path = [pathComponentsM componentsJoinedByString:@"/"];
    components.query = nil;
    return components.URL;
}

inline static NSURL *_getTsRemoteURL(NSURL *downloadURL, NSString *tsName) {
    NSURLComponents *components = [NSURLComponents componentsWithString:downloadURL.absoluteString];
    components.path = [[components.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:tsName];
    return components.URL;
}

inline static NSString *_getDownloadFolder() {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"downloadFolder"];
}

inline static NSString *_getTssDownloadFolder(NSURL *remoteURL) {
    NSArray<NSString *> *components = remoteURL.pathComponents;
    return [_getDownloadFolder() stringByAppendingFormat:@"/%@", components[components.count - 2]];
}

inline static NSString *_getCacheFolder() {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"cacheFolder"];
}

inline static NSString *_getTssCacheFolder(NSURL *remoteURL) {
    NSArray<NSString *> *components = remoteURL.pathComponents;
    return [_getCacheFolder() stringByAppendingFormat:@"/%@", components[components.count - 2]];
}

inline static NSString *_getTsCachePath(NSURL *remoteURL, NSString *tsName) {
    return [_getTssCacheFolder(remoteURL) stringByAppendingPathComponent:tsName];
}

inline static void _createFileAtPath(NSString *filePath) {
    if ( [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) { return;}
    [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
}

inline static int _localServerPort(void) {
    return 54321;
}

inline static NSString *_localServerPath(void) {
    return [NSString stringWithFormat:@"http://127.0.0.1:%d", _localServerPort()];
}

inline static NSString *_getVideoFileName(NSURL *remoteURL) {
    return _getTssDownloadFolder(remoteURL).lastPathComponent;
}

#pragma mark -

@interface SJDownloadServer ()

@property (nonatomic, strong, readonly)  NSMutableDictionary<NSString *, NSMutableArray<SJTsEntity *> *> *downloadingVideosM;
@property (nonatomic, strong, readonly)  HTTPServer *httpServer;

@end

@implementation SJDownloadServer

+ (instancetype)sharedServer {
    static id _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [SJDownloadServer new];
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if ( !self ) return nil;
    NSString *downloadFolder = _getDownloadFolder();
    NSString *cacheFolder = _getCacheFolder();
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:downloadFolder] ) _createFileAtPath(downloadFolder);
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] ) _createFileAtPath(cacheFolder);
    if ( ![self.httpServer start:nil] ) { NSLog(@"服务器启动失败!"); return nil;}
    return self;
}

@synthesize httpServer = _httpServer;

- (HTTPServer *)httpServer {
    if ( _httpServer ) return _httpServer;
    _httpServer = [HTTPServer new];
    [_httpServer setType:@"_http._tcp."];
    [_httpServer setPort:_localServerPort()];
    [_httpServer setDocumentRoot:_getDownloadFolder()];
    return _httpServer;
}

@synthesize downloadingVideosM = _downloadingVideosM;

/*!
 *  key : fileName */
- (NSMutableDictionary<NSString *,NSMutableArray<SJTsEntity *> *> *)downloadingVideosM {
    if ( _downloadingVideosM ) return _downloadingVideosM;
    _downloadingVideosM = [NSMutableDictionary new];
    return _downloadingVideosM;
}

@end






















#pragma mark -


@interface NSTimer (SJDownloadServerAdd)

+ (NSTimer *)sjDownloadServer_scheduledTimerWithTimeInterval:(NSTimeInterval)ti exeBlock:(void(^)(NSTimer *timer))block repeats:(BOOL)yesOrNo;

@end

@implementation NSTimer (SJDownloadServerAdd)

+ (NSTimer *)sjDownloadServer_scheduledTimerWithTimeInterval:(NSTimeInterval)ti exeBlock:(void(^)(NSTimer *timer))block repeats:(BOOL)yesOrNo {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(sjDownloadServer_exeTimerBlock:) userInfo:[block copy] repeats:yesOrNo];
    return timer;
}

+ (void)sjDownloadServer_exeTimerBlock:(NSTimer *)timer {
    void(^block)(NSTimer *timer) = timer.userInfo;
    if ( !block ) return;
    block(timer);
}

@end






#pragma mark -



@interface SJTsEntity (SJDownloadServerAdd)

@property (nonatomic, assign, readwrite) long long totalSize;
@property (nonatomic, assign, readwrite) long long downloadSize;
@property (nonatomic, assign, readonly)  float downloadProgress;
@property (nonatomic, strong, readwrite)  NSOutputStream *outputStream;
@property (nonatomic, strong, readonly)  NSString *cachePath;

@property (nonatomic, assign, readwrite) SJDownloadState downloadState;

- (long long)cacheSize;

@property (nonatomic, copy, readwrite) void(^suspendCompletionBlock)(SJTsEntity *ts);

- (void)closeOutputStream;

@end

@implementation SJTsEntity (SJDownloadServerAdd)

- (long long)totalSize {
    return [objc_getAssociatedObject(self, _cmd) longLongValue];
}

- (void)setTotalSize:(long long)totalSize {
    objc_setAssociatedObject(self, @selector(totalSize), @(totalSize), OBJC_ASSOCIATION_RETAIN);
}

- (long long)downloadSize {
    return [objc_getAssociatedObject(self, _cmd) longLongValue];
}

- (void)setDownloadSize:(long long)downloadSize {
    objc_setAssociatedObject(self, @selector(downloadSize), @(downloadSize), OBJC_ASSOCIATION_RETAIN);
}

- (float)downloadProgress {
    if ( 0 == self.totalSize ) return 0;
    return self.downloadSize * 1.0 / self.totalSize;
}

- (void)setOutputStream:(NSOutputStream *)outputStream {
    objc_setAssociatedObject(self, @selector(outputStream), outputStream, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSOutputStream *)outputStream {
    NSOutputStream *outputStream = objc_getAssociatedObject(self, _cmd);
    return outputStream;
}

- (void)closeOutputStream {
    [self.outputStream close];
    self.outputStream = nil;
}

- (long long)cacheSize {
    NSDictionary<NSFileAttributeKey, id> *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:self.cachePath error:nil];
    return [attr[NSFileSize] longLongValue];
}

- (NSString *)cachePath {
    return _getTsCachePath(self.remoteURL, self.name);
}

- (SJDownloadState)downloadState {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (void)setDownloadState:(SJDownloadState)downloadState {
    objc_setAssociatedObject(self, @selector(downloadState), @(downloadState), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setSuspendCompletionBlock:(void (^)(SJTsEntity *))suspendCompletionBlock {
    objc_setAssociatedObject(self, @selector(suspendCompletionBlock), suspendCompletionBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(SJTsEntity *))suspendCompletionBlock {
    return objc_getAssociatedObject(self, _cmd);
}

@end




#pragma mark -


@interface NSURLSessionTask (SJDownloadServerAdd)

@property (nonatomic, strong, readwrite) SJTsEntity *ts;
@property (nonatomic, copy, readwrite) void(^__nullable progressBlock)(SJTsEntity *ts, float progress);
@property (nonatomic, copy, readwrite) void(^__nullable completionBlock)(SJTsEntity *ts, NSString *dataPath);
@property (nonatomic, copy, readwrite) void(^__nullable errorBlock)(SJTsEntity *ts, NSError *error);

@end

@implementation NSURLSessionTask (SJDownloadServerAdd)

- (SJTsEntity *)ts {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTs:(SJTsEntity *)ts {
    objc_setAssociatedObject(self, @selector(ts), ts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(SJTsEntity *, float))progressBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setProgressBlock:(void (^)(SJTsEntity *, float))progressBlock {
    objc_setAssociatedObject(self, @selector(progressBlock), progressBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(SJTsEntity *, NSString *))completionBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCompletionBlock:(void (^)(SJTsEntity *, NSString *))completionBlock {
    objc_setAssociatedObject(self, @selector(completionBlock), completionBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(SJTsEntity *, NSError *))errorBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setErrorBlock:(void (^)(SJTsEntity *, NSError *))errorBlock {
    objc_setAssociatedObject(self, @selector(errorBlock), errorBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end




#pragma mark -

@interface SJDownloadServer (Download) <NSURLSessionDelegate>

@property (nonatomic, strong, readonly) NSURLSession *session;

@property (nonatomic, strong, readonly) NSMutableSet<NSURLSessionTask *> *tasksM;

- (void)downloadDataWithTs:(SJTsEntity *)ts downloadProgress:(void(^ __nullable)(SJTsEntity *ts, float progress))progressBlock completion:(void(^__nullable)(SJTsEntity *ts, NSString *dataPath))completionBlock errorBlock:(void(^__nullable)(SJTsEntity *ts, NSError *error))errorBlock;

- (void)suspendWithTs:(SJTsEntity *)ts completion:(void(^__nullable)(SJTsEntity *ts))completionBlock;

@end


@implementation SJDownloadServer (Download)

- (NSURLSession *)session {
    NSURLSession *session = objc_getAssociatedObject(self, _cmd);
    if ( session ) return session;
    session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    objc_setAssociatedObject(self, _cmd, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return session;
}

- (NSMutableSet<NSURLSessionTask *> *)tasksM {
    NSMutableSet<NSURLSessionTask *> *tasksM = objc_getAssociatedObject(self, _cmd);
    if ( tasksM ) return tasksM;
    tasksM = [NSMutableSet set];
    objc_setAssociatedObject(self, _cmd, tasksM, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return tasksM;
}

- (void)downloadDataWithTs:(SJTsEntity *)ts downloadProgress:(void (^)(SJTsEntity *, float))progressBlock completion:(void (^)(SJTsEntity *, NSString *))completionBlock errorBlock:(void (^)(SJTsEntity *, NSError *))errorBlock {
    NSMutableURLRequest *requestM = [NSMutableURLRequest requestWithURL:ts.remoteURL];
    [requestM setValue:[NSString stringWithFormat:@"bytes=%lld-", ts.cacheSize] forHTTPHeaderField:@"Range"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:requestM];
    task.ts = ts;
    task.progressBlock = progressBlock;
    task.completionBlock = completionBlock;
    task.errorBlock = errorBlock;
    [task resume];
    [self.tasksM addObject:task];
    if ( task.ts.outputStream ) [task.ts closeOutputStream];
}

- (void)suspendWithTs:(SJTsEntity *)ts completion:(void(^__nullable)(SJTsEntity *ts))completionBlock {
    ts.downloadState = SJDownloadState_Suspend;
    ts.suspendCompletionBlock = completionBlock;
    [self.tasksM enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull task, BOOL * _Nonnull stop) {
        [task cancel];
        [ts closeOutputStream];
    }];
}

#pragma mark - data Task delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    long long cacheSize = dataTask.ts.cacheSize;
    dataTask.ts.totalSize = response.expectedContentLength + cacheSize;
    dataTask.ts.downloadSize = cacheSize;
    /*!
     *  参数 append 如果为YES 表示 a, 只写模式. 如果文件存在, 则文件指针被放置在文件的末尾. 也就是说, 这是追加模式. 如果文件不存在, 则创建一个新文件用于写入.  */
    dataTask.ts.outputStream = [NSOutputStream outputStreamToFileAtPath:dataTask.ts.cachePath append:YES];
    [dataTask.ts.outputStream open];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if ( 0 == data.length ) return;
    dataTask.ts.downloadSize += data.length;
    [dataTask.ts.outputStream write:data.bytes maxLength:data.length];
    if ( dataTask.progressBlock ) dataTask.progressBlock(dataTask.ts, dataTask.ts.downloadProgress);
    dataTask.ts.downloadState = SJDownloadState_Downloading;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDataTask *)dataTask didCompleteWithError:(NSError *)error {
    [self.tasksM removeObject:dataTask];
    [dataTask.ts.outputStream close];
    dataTask.ts.outputStream = nil;
    
    switch (dataTask.state) {
        case NSURLSessionTaskStateCompleted: {
            if ( error ) {
                if ( dataTask.ts.downloadState == SJDownloadState_Suspend ) {
                    if ( dataTask.ts.suspendCompletionBlock ) dataTask.ts.suspendCompletionBlock(dataTask.ts);
                }
                // 暂停也是 error 的一种. 一起回调 error block. 上游处理去. 
                if ( dataTask.errorBlock ) dataTask.errorBlock(dataTask.ts, error);
                return;
            }
            NSString *cachePath = _getTsCachePath(dataTask.ts.remoteURL, dataTask.ts.name);
            if ( dataTask.completionBlock ) dataTask.completionBlock(dataTask.ts, cachePath);
        }
            break;
        case NSURLSessionTaskStateRunning:   break;
        case NSURLSessionTaskStateSuspended: break;
        case NSURLSessionTaskStateCanceling: break;
    }
}

@end






#pragma mark -

@implementation SJDownloadServer (DownloadMethods)

- (void)downloadWithURLStr:(NSString *)URLStr downloadProgress:(void(^)(float progress))progressBlock completion:(void(^)(NSString *dataPath))completionBlock errorBlock:(void(^)(NSError *error))errorBlock {
    [self downloadWithURLStr:URLStr downloadMode:SJDownloadMode450 downloadProgress:progressBlock completion:completionBlock errorBlock:errorBlock];
}

- (void)downloadWithURLStr:(NSString *)URLStr downloadMode:(SJDownloadMode)mode downloadProgress:(void(^)(float progress))progressBlock completion:(void(^)(NSString *dataPath))completionBlock errorBlock:(void(^)(NSError *error))errorBlock {
    if ( 0 == URLStr.length ) {
        if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"下载地址为空, 无法下载!"));
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURL *downloadURL = _getTssDownloadURLStr(URLStr, mode);
        if ( nil == downloadURL ) {
            if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"路径转换出错, 无法下载!"));
            return ;
        }
        NSError *error = nil;
        NSString *tsDataStr = [NSString stringWithContentsOfURL:downloadURL encoding:NSUTF8StringEncoding error:&error];
        if ( error ) {
            if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeUnknown, [NSString stringWithFormat:@"网络错误, 无法下载! 请检查ATS||URL是否正确:%@", downloadURL.absoluteString]));
            return;
        }
        
        NSString *tssCacheFolder = _getTssCacheFolder(downloadURL);
        _createFileAtPath(tssCacheFolder);
        
        NSMutableArray<SJTsEntity *> *tsM = self.downloadingVideosM[_getVideoFileName(downloadURL)];
        
        /*!
         *  tsM 存在两种
         *  第一种是 下载过但是被暂停了.
         *  第二种就是 新建的下载.
         *
         *  第一种的下载需要恢复下载. */
        
        if ( 0 == tsM.count ) {
            // 没有下载过.  新建的下载.
            tsM = [NSMutableArray array];
            NSString *modeStr = _getModeStr(mode);
            NSString *m3u8CachePath = [tssCacheFolder stringByAppendingPathComponent:modeStr];
            if ( ![tsDataStr writeToFile:m3u8CachePath atomically:YES encoding:NSUTF8StringEncoding error:nil] ) {
                if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeFileOperationError, [NSString stringWithFormat:@"m3u8文件保存失败, 请检查路径是否正确: %@", m3u8CachePath]));
                return;
            }
            
            NSArray<NSString *> *tsDataArr = [tsDataStr componentsSeparatedByString:@"\n"];
            [tsDataArr enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ( 0 == idx ) return;
                NSString *tsName = obj;
                NSString *tsDurationStr = tsDataArr[idx - 1];
                if ( ![tsName hasSuffix:@".ts"] ) return;
                if ( ![tsDurationStr hasPrefix:@"#EXTINF"] ) return;
                int duration = [tsDurationStr substringFromIndex:8].intValue;
                NSURL *remoteURL = _getTsRemoteURL(downloadURL, tsName);
                if ( !remoteURL ) {
                    if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"拼接Ts下载路径出错！请检查."));
                    *stop = YES;
                    return;
                }
                SJTsEntity *ts = [[SJTsEntity alloc] initWithDuration:duration remoteURL:remoteURL name:tsName];
                if ( !ts ) {
                    if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeUnknown, @"..."));
                    *stop = YES;
                    return;
                }
                // add to container
                [tsM addObject:ts];
            }];
        }
        else {
            [tsM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.downloadState = SJDownloadState_Unknown;
            }];
        }
        
        NSMutableArray<SJTsEntity *> *tmpTsM = tsM.mutableCopy;
        self.downloadingVideosM[_getVideoFileName(downloadURL)] = tmpTsM;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSTimer *timer = ({
                // 汇报下载进度
                NSTimer *timer = [NSTimer sjDownloadServer_scheduledTimerWithTimeInterval:1 exeBlock:^(NSTimer *timer) {
                    if ( 0 == tmpTsM.count ) { [timer invalidate]; return;}
                    __block float tProgress = 0;
                    [tmpTsM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        tProgress += obj.downloadProgress;
                    }];
                    tProgress = tProgress * 1.0 / tmpTsM.count;
                    if ( tProgress >= 1 ) {
                        [timer invalidate];
                        tProgress = 1;
                    }
                    if ( progressBlock ) progressBlock(tProgress);
                    if ( tmpTsM.firstObject.downloadState != SJDownloadState_Unknown && tmpTsM.firstObject.downloadState == SJDownloadState_Suspend ) { [timer invalidate];}
                } repeats:YES];
                [timer fire];
                timer;
            });
            
            __weak typeof (self) _self = self;
            [tsM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self downloadDataWithTs:obj downloadProgress:nil completion:^(SJTsEntity *ts, NSString *dataPath) {
                    __strong typeof (_self) self = _self;
                    if ( !self ) return;
                    NSLog(@"___ : %zd", ts.downloadState);
                    /// 下载完毕
                    ts.downloadState = SJDownloadState_Downloaded;
                    /// 下载完一个删一个
                    [tmpTsM removeObject:ts];
                    /// 还没下载完, 继续下载.
                    if ( 0 != tmpTsM.count ) return;
                    /// 当 tmpTsM 总数为0时, 代表下载完毕.
                    /// 下面是将下载的文件 移动到 documents 中.
                    [timer invalidate];
                    
                    NSString *tssDownloadFolder = _getTssDownloadFolder(downloadURL);
                    NSString *tssCacheFolder = _getTssCacheFolder(downloadURL);
                    if ( [[NSFileManager defaultManager] fileExistsAtPath:tssDownloadFolder] ) {
                        [[NSFileManager defaultManager] removeItemAtPath:tssDownloadFolder error:nil];
                    }
                    NSError *error;
                    [[NSFileManager defaultManager] moveItemAtPath:tssCacheFolder toPath:tssDownloadFolder error:&error];
                    if ( progressBlock ) progressBlock(1.0f);
                    NSString *localServerPath = [NSString stringWithFormat:@"%@/%@/%@", _localServerPath(), _getVideoFileName(downloadURL), _getModeStr(mode)];
                    if ( completionBlock ) completionBlock(localServerPath);
                    
                } errorBlock:^(SJTsEntity *ts, NSError *error) {
                    [timer invalidate];

                    /// 下载被暂停
                    if ( SJDownloadCancelCode == error.code ) { return ; }
                    
                    if ( errorBlock ) errorBlock(error);
                }];
            }];
        });
    });
}

- (void)suspendWithURLStr:(NSString *)URLStr downloadMode:(SJDownloadMode)mode completion:(void(^__nullable)(void))completionBlock errorBlock:(void(^__nullable)(NSError *error))errorBlock {
    if ( 0 == URLStr.length ) {
        if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"下载地址为空, 无法暂停下载!"));
        return;
    }
    
    /// get downloading tss
    NSURL *downloadURL = _getTssDownloadURLStr(URLStr, mode);
    if ( nil == downloadURL ) {
        if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"路径转换出错, 无法暂停下载!"));
        return ;
    }
    
    NSMutableArray<SJTsEntity *> *tssM = self.downloadingVideosM[_getVideoFileName(downloadURL)].mutableCopy;
    [tssM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [tssM removeObject:obj];
        [self suspendWithTs:obj completion:^(SJTsEntity *ts) {
            if ( 0 != tssM.count ) return;
            if ( completionBlock ) completionBlock();
        }];
    }];
}

@end


#pragma mark -


@implementation SJDownloadServer (FileOperation)

- (NSString *)cacheFolderPath {
    return _getCacheFolder();
}

- (NSString *)downloadFolderPath {
    return _getDownloadFolder();
}

@end

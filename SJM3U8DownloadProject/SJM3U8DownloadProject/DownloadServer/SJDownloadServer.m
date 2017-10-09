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

static int const SJDownloadCancelCode = -999;

NSErrorDomain const SJDownloadErrorDomain = @"SJDownloadErrorDomain";

NSErrorUserInfoKey const SJDownloadErrorInfoKey = @"SJDownloadErrorInfoKey";

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

/*!
 *  获取视频真实的 m3u8文件的下载地址
 *
 *  当前地址:
 *  http://asp.cntv.lxdns.com/asp/hls/main/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/main.m3u8?maxbr=850
 *  根据 参数 URLStr + mode, 拼接 m3u8文件下载地址:
 *  http://asp.cntv.lxdns.com//asp/hls/450/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/450.m3u8
 *
 *  把 hls 后面的 main 改成了 450。 最后的路径改成了 450.m3u8（不知道路径是不是固定的） */
inline static NSURL *_getM3u8DownloadURLStr(NSString *URLStr, SJDownloadMode mode) {
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


#pragma mark - 下面函数 依赖上面两个函数[ _getM3u8DownloadURLStr() 和 _getModeStr() ], 视频保存和缓存的目录不变的话不用管.

/*!
 *  根据视频下载地址和ts名字, 拼接ts的下载地址. */
inline static NSURL *_getTsRemoteURL(NSURL *downloadURL, NSString *tsName) {
    NSURLComponents *components = [NSURLComponents componentsWithString:downloadURL.absoluteString];
    components.path = [[components.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:tsName];
    return components.URL;
}

/*!
 *  下载根目录 */
inline static NSString *_getDownloadFolder() {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"downloadFolder"];
}

/*!
 *  某个视频的根目录 */
inline static NSString *_getVideoDownloadFolder(NSURL *remoteURL) {
    NSArray<NSString *> *components = remoteURL.pathComponents;
    return [_getDownloadFolder() stringByAppendingFormat:@"/%@", components[components.count - 2]];
}

/*!
 *  缓存根目录 */
inline static NSString *_getCacheFolder() {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"cacheFolder"];
}

/*!
 *  某个视频的缓存根目录 */
inline static NSString *_getVideoCacheFolder(NSURL *remoteURL) {
    NSArray<NSString *> *components = remoteURL.pathComponents;
    return [_getCacheFolder() stringByAppendingFormat:@"/%@", components[components.count - 2]];
}

/*!
 *  某个 Ts 文件的路径 */
inline static NSString *_getTsCachePath(NSURL *remoteURL, NSString *tsName) {
    return [_getVideoCacheFolder(remoteURL) stringByAppendingPathComponent:tsName];
}

/*!
 *  根据路径创建目录
 *
 *  创建目录, 这个函数如果文件已存在, 不会再次创建 */
inline static void _createFileAtPath(NSString *filePath) {
    if ( [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) { return;}
    [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
}

/*!
 *  本地服务器端口 */
inline static int _localServerPort(void) {
    return 54321;
}

/*!
 *  本地服务器地址 */
inline static NSString *_localServerPath(void) {
    return [NSString stringWithFormat:@"http://127.0.0.1:%d", _localServerPort()];
}

/*!
 * 获取远程服务器保存的文件名 */
inline static NSString *_getVideoFileName(NSURL *remoteURL) {
    return _getVideoDownloadFolder(remoteURL).lastPathComponent;
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
 *  key : fileName
 *
 *  这个字典存着所有解析过的 ts对象. key是保存在本地的总文件名. */
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

- (void)downloadWithURLStr:(NSString *)URLStr
          downloadProgress:(void(^ __nullable)(float progress))progressBlock
                completion:(void(^__nullable)(NSString *playAddressStr, NSString *localPath))completionBlock
                errorBlock:(void(^__nullable)(NSError *error))errorBlock {
    [self downloadWithURLStr:URLStr downloadMode:SJDownloadMode450 downloadProgress:progressBlock completion:completionBlock errorBlock:errorBlock];
}

- (void)downloadWithURLStr:(NSString *)URLStr
              downloadMode:(SJDownloadMode)mode
          downloadProgress:(void(^__nullable)(float progress))progressBlock
                completion:(void(^__nullable)(NSString *playAddressStr, NSString *localPath))completionBlock
                errorBlock:(void(^__nullable)(NSError *error))errorBlock; {
    if ( 0 == URLStr.length ) {
        if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"下载地址为空, 无法下载!"));
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        /*!
         *  获取m3u8的下载地址 */
        NSURL *m3u8DownloadAddreesURL = _getM3u8DownloadURLStr(URLStr, mode);
        if ( nil == m3u8DownloadAddreesURL ) {
            if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"路径转换出错, 无法下载!"));
            return ;
        }
        NSError *error = nil;
        NSString *m3u8DataStr = [NSString stringWithContentsOfURL:m3u8DownloadAddreesURL encoding:NSUTF8StringEncoding error:&error];
        if ( error ) {
            if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeUnknown, [NSString stringWithFormat:@"网络错误, 无法下载! 请检查ATS||URL是否正确:%@", m3u8DownloadAddreesURL.absoluteString]));
            return;
        }
        
        /*!
         *  获取该视频将要缓存的目录 */
        NSString *tssCacheFolder = _getVideoCacheFolder(m3u8DownloadAddreesURL);
        //  创建
        _createFileAtPath(tssCacheFolder);
        
        /*!
         *  查看是否之前 解析过 ts 文件.
         *  有两种情况
         *  第一种是 下载过但是被暂停了. 已经解析了.
         *  第二种是 没下载过.
         *
         *  第一种的下载需要恢复下载.
         *  第二种的直接下载 */
        NSMutableArray<SJTsEntity *> *tsM = self.downloadingVideosM[_getVideoFileName(m3u8DownloadAddreesURL)];
        
        // 直接下载
        if ( 0 == tsM.count ) {
            // 没有下载过.
            tsM = [NSMutableArray array];
            NSString *modeStr = _getModeStr(mode);
            NSString *m3u8SavePath = [tssCacheFolder stringByAppendingPathComponent:modeStr];
            // 把服务器的m3u8文件直接保存到将要下载的cache目录下
            if ( ![m3u8DataStr writeToFile:m3u8SavePath atomically:YES encoding:NSUTF8StringEncoding error:nil] ) {
                if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeFileOperationError, [NSString stringWithFormat:@"m3u8文件保存失败, 请检查路径是否正确: %@", m3u8SavePath]));
                return;
            }
            // 解析 m3u8文件. 获取 tsArr
            NSArray<NSString *> *tsDataArr = [m3u8DataStr componentsSeparatedByString:@"\n"];
            [tsDataArr enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ( 0 == idx ) return;
                NSString *tsName = obj;
                NSString *tsDurationStr = tsDataArr[idx - 1];
                if ( ![tsName hasSuffix:@".ts"] ) return;
                if ( ![tsDurationStr hasPrefix:@"#EXTINF"] ) return;
                int duration = [tsDurationStr substringFromIndex:8].intValue;
                NSURL *remoteURL = _getTsRemoteURL(m3u8DownloadAddreesURL, tsName);
                if ( !remoteURL ) {
                    if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"拼接Ts下载路径出错！请检查."));
                    *stop = YES;
                    return;
                }
                // 转为模型
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
        // 如果下载过
        else {
            [tsM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                // 重置下载状态
                obj.downloadState = SJDownloadState_Unknown;
            }];
        }
        
        /*!
         *  copy一份. 某个 ts 下载完成后, 会从 tmpTsM 中删掉.
         *  如果这个数组里面没有元素的, 说明下载完成了. */
        NSMutableArray<SJTsEntity *> *tmpTsM = tsM.mutableCopy;
        self.downloadingVideosM[_getVideoFileName(m3u8DownloadAddreesURL)] = tmpTsM;
        
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
                // 前往下载
                [self downloadDataWithTs:obj downloadProgress:nil completion:^(SJTsEntity *ts, NSString *dataPath) {
                    /// 下载完毕回调
                    __strong typeof (_self) self = _self;
                    if ( !self ) return;
                    ts.downloadState = SJDownloadState_Downloaded;
                    /// 下载完一个删一个. 等待下载完毕...
                    [tmpTsM removeObject:ts];
                    if ( 0 != tmpTsM.count ) return; // 如果等于0, 说明下载完毕, 开始跑下面的代码.
                    
                    /// 下面是将下载的文件 移动到 documents 中.
                    [timer invalidate];
                    
                    /// 视频将要保存的目录
                    NSString *videoDownloadFolder = _getVideoDownloadFolder(m3u8DownloadAddreesURL);
                    /// 缓存的目录
                    NSString *videoCacheFolder = _getVideoCacheFolder(m3u8DownloadAddreesURL);
                    
                    if ( [[NSFileManager defaultManager] fileExistsAtPath:videoDownloadFolder] ) {
                        /// 如果存在同名文件, 直接删掉.
                        [[NSFileManager defaultManager] removeItemAtPath:videoDownloadFolder error:nil];
                    }
                    
                    NSError *error;
                    /// 将 cache 移到 documents 中.
                    [[NSFileManager defaultManager] moveItemAtPath:videoCacheFolder toPath:videoDownloadFolder error:&error];
                    /// 进度回调一下.
                    if ( progressBlock ) progressBlock(1.0f);
                    NSString *localServerPath = [NSString stringWithFormat:@"%@/%@/%@", _localServerPath(), _getVideoFileName(m3u8DownloadAddreesURL), _getModeStr(mode)];
                    /// 下载完成回调.
                    if ( completionBlock ) completionBlock(localServerPath, dataPath);
                    
                } errorBlock:^(SJTsEntity *ts, NSError *error) {
                    [timer invalidate];

                    /*!
                     *  如果 error.code == -999 表示 用户点击了暂停.
                     *  URLDataTask 调用了 cancel 就报 code -999 错误.
                     *  暂停就直接 return 了. */
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
    NSURL *downloadURL = _getM3u8DownloadURLStr(URLStr, mode);
    if ( nil == downloadURL ) {
        if ( errorBlock ) errorBlock(_downloadServerError(SJDownloadErrorCodeURLError, @"路径转换出错, 无法暂停下载!"));
        return ;
    }
    
    /// 获取下载中的 ts 们
    NSMutableArray<SJTsEntity *> *tssM = self.downloadingVideosM[_getVideoFileName(downloadURL)].mutableCopy;
    [tssM enumerateObjectsUsingBlock:^(SJTsEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [tssM removeObject:obj];
        /// 一个一个的取消掉.
        [self suspendWithTs:obj completion:^(SJTsEntity *ts) {
            if ( 0 != tssM.count ) return; /// 如果 等于0, 说明都取消掉了, 调用 completion 的回调.
            if ( completionBlock ) completionBlock();
        }];
    }];
}

@end

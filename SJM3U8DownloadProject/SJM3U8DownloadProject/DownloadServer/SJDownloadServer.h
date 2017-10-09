//
//  SJDownloadServer.h
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/5.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const SJDownloadErrorDomain;

extern NSErrorUserInfoKey const SJDownloadErrorInfoKey;


typedef NS_ENUM(NSUInteger, SJDownloadMode) {
    SJDownloadMode450,
    SJDownloadMode200,
    SJDownloadMode850,
};

typedef NS_ENUM(NSUInteger, SJDownloadErrorCode) {
    SJDownloadErrorCodeUnknown,
    SJDownloadErrorCodeURLError,
    SJDownloadErrorCodeDownloadError,
    SJDownloadErrorCodeFileOperationError
};


@interface SJDownloadServer : NSObject

+ (instancetype)sharedServer;

@end


@interface SJDownloadServer (DownloadMethods)

/*!
 *  default mode is 450 */
- (void)downloadWithURLStr:(NSString *)URLStr
          downloadProgress:(void(^ __nullable)(float progress))progressBlock
                completion:(void(^__nullable)(NSString *dataPath))completionBlock
                errorBlock:(void(^__nullable)(NSError *error))errorBlock;

- (void)downloadWithURLStr:(NSString *)URLStr
              downloadMode:(SJDownloadMode)mode
          downloadProgress:(void(^__nullable)(float progress))progressBlock
                completion:(void(^__nullable)(NSString *dataPath))completionBlock
                errorBlock:(void(^__nullable)(NSError *error))errorBlock;

/*!
 *  暂停下载, 文件暂存在 cache 目录中, 等下载完成, 会自动移动到 documents 中. */
- (void)suspendWithURLStr:(NSString *)URLStr downloadMode:(SJDownloadMode)mode completion:(void(^__nullable)(void))completionBlock errorBlock:(void(^__nullable)(NSError *error))errorBlock;

@end



@interface SJDownloadServer (FileOperation)

/*!
 *  所有缓存的根目录 */
- (NSString *)cacheFolderPath;

/*!
 *  所有下载的文件的根目录 */
- (NSString *)downloadFolderPath;

@end


NS_ASSUME_NONNULL_END

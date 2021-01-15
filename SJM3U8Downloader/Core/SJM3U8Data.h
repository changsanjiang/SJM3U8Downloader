//
//  SJM3U8Data.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import "SJM3U8Download.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJM3U8Data : NSObject<SJM3U8DownloadTaskDelegate>

+ (NSData *)dataWithContentsOfRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority error:(NSError **)error willPerformHTTPRedirection:(void(^_Nullable)(NSHTTPURLResponse *response, NSURLRequest *newRequest))block;

@end

NS_ASSUME_NONNULL_END

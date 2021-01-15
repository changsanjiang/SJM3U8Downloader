//
//  SJM3U8Configuration.h
//  SJM3U8Downloader
//
//  Created by BlueDancer on 2021/1/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJM3U8Configuration : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, nullable) BOOL(^allowDownloads)(NSURLResponse *response);

@end

NS_ASSUME_NONNULL_END

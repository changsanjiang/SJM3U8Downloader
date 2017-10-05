//
//  SJTsEntity.h
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/5.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJTsEntity : NSObject

- (instancetype)initWithDuration:(int)duration remoteURL:(NSURL *)URL name:(NSString *)name;

@property (nonatomic, assign, readonly) int duration;
@property (nonatomic, strong, readonly) NSURL *remoteURL;
@property (nonatomic, strong, readonly) NSString *name;

@end

NS_ASSUME_NONNULL_END

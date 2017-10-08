//
//  SJUser.m
//  SJM3U8DownloadProject
//
//  Created by BlueDancer on 2017/10/8.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import "SJUser.h"
#import "SJVideoInfo.h"

@implementation SJUser

+ (NSString *)primaryKey {
    return @"userId";
}

+ (NSDictionary<NSString *,Class> *)arrayCorrespondingKeys {
    return @{@"downloadedVideos":[SJVideoInfo class]};
}

@end

//
//  SJM3U8Configuration.m
//  SJM3U8Downloader
//
//  Created by BlueDancer on 2021/1/15.
//

#import "SJM3U8Configuration.h"

@implementation SJM3U8Configuration

+ (instancetype)shared {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = SJM3U8Configuration.alloc.init;
    });
    return instance;
}

@end

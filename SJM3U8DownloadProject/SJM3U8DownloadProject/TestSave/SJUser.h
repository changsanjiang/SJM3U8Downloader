//
//  SJUser.h
//  SJM3U8DownloadProject
//
//  Created by BlueDancer on 2017/10/8.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SJDBMap/SJDBMap.h>

@class SJVideoInfo;

@interface SJUser : NSObject<SJDBMapUseProtocol>

@property (nonatomic, assign) NSInteger userId;

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSMutableArray<SJVideoInfo *> *downloadedVideos;

@end

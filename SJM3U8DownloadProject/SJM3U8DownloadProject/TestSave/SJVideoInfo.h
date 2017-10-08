//
//  SJVideoInfo.h
//  SJM3U8DownloadProject
//
//  Created by BlueDancer on 2017/10/8.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <SJDBMap/SJDBMap.h>

@interface SJVideoInfo : NSObject<SJDBMapUseProtocol>

@property (nonatomic, assign) NSInteger videoId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *fileSavePath;
@property (nonatomic, strong) NSString *remoteURLStr;

@end

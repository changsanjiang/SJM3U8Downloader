//
//  SJM3U8DownloadListItem+TestExtended.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/19.
//  Copyright © 2019 SanJiang. All rights reserved.
//
 
#import "SJM3U8DownloadListItem.h"

NS_ASSUME_NONNULL_BEGIN

///
/// 添加一下附加字段
///
@interface SJM3U8DownloadListItem (TestExtended)
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *title;
@end

NS_ASSUME_NONNULL_END

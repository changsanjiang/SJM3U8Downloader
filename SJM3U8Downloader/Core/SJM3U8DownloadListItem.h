//
//  SJM3U8DownloadListItem.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/18.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SJUIKit/SJSQLiteTableModelProtocol.h>
#import "SJM3U8DownloadListControllerDefines.h"
#import "SJM3U8DownloadListOperation.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8DownloadListItem : NSObject<SJM3U8DownloadListItem, SJSQLiteTableModelProtocol>
- (instancetype)initWithUrl:(NSString *)url folderName:(nullable NSString *)name;
@property (nonatomic, weak, nullable) id<SJM3U8DownloadListItemDelegate> delegate;
@property (nonatomic, copy, readonly, nullable) NSString *folderName;

@property (nonatomic, readonly) NSInteger id;
@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic) SJDownloadState state;
@property (nonatomic) float progress;
@property (nonatomic) double speed;
@property (nonatomic, strong, nullable) SJM3U8DownloadListOperation *operation;
@end
NS_ASSUME_NONNULL_END

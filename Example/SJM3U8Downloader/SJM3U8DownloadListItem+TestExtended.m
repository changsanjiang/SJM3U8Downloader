//
//  SJM3U8DownloadListItem+TestExtended.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/19.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8DownloadListItem+TestExtended.h"
#import <objc/message.h>

@implementation SJM3U8DownloadListItem (TestExtended)
- (void)setName:(NSString *)name {
    objc_setAssociatedObject(self, @selector(name), name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)name {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTitle:(NSString *)title {
    objc_setAssociatedObject(self, @selector(title), title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)title {
    return objc_getAssociatedObject(self, _cmd);

}
@end

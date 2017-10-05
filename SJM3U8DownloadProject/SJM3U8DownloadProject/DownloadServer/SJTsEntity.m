//
//  SJTsEntity.m
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/5.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import "SJTsEntity.h"

@implementation SJTsEntity

- (instancetype)initWithDuration:(int)duration remoteURL:(NSURL *)URL name:(nonnull NSString *)name {
    self = [super init];
    if ( !self ) return nil;
    _duration = duration;
    _remoteURL = URL;
    _name = name;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@ <%p>]:{\n\tduration:%zd,\n\tremoteURL:%@\n\tname:%@\n}", [self class], self, _duration, _remoteURL, _name];
}
@end

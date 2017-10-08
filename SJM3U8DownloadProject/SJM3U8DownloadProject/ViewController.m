//
//  ViewController.m
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/3.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import "ViewController.h"
#import "SJDownloadServer.h"
#import <AVFoundation/AVFoundation.h>
#import "SJUser.h"
#import "SJVideoInfo.h"
#import <SJDBMap/SJDBMap.h>

@interface ViewController ()

@property (nonatomic, strong, readonly) SJUser *xiaoMing;
@property (nonatomic, strong, readonly) SJVideoInfo *video;

@end

@implementation ViewController

- (IBAction)clickedDoanload:(id)sender {
    
    __weak typeof(self) _self = self;
    [[SJDownloadServer sharedServer] downloadWithURLStr:self.video.remoteURLStr downloadMode:SJDownloadMode450 downloadProgress:^(float progress) {
        NSLog(@"Ing: %.02f", progress);
    } completion:^(NSString *dataPath) {
        NSLog(@"End: %@", dataPath);
        
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.video.fileSavePath = dataPath;
        [[SJDatabaseMap sharedServer] insertOrUpdateDataWithModel:self.xiaoMing callBlock:^(BOOL result) {
            if ( result ) NSLog(@"下载成功!");
            else NSLog(@"下载失败!");
        }];
        
    } errorBlock:^(NSError *error) {
        NSLog(@"Error: %@", error.userInfo[SJDownloadErrorInfoKey]);
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"\n%@", NSHomeDirectory());
    
  
    /*!
     http://asp.cntv.lxdns.com/asp/hls/main/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/main.m3u8
     
     #EXTM3U
     #EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=460800, RESOLUTION=480x360
     /asp/hls/450/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/450.m3u8
     
     */
    
    /*!
     http://asp.cntv.lxdns.com/asp/hls/450/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/450.m3u8
     http://asp.cntv.lxdns.com/asp/hls/450/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/0.ts

     #EXTM3U
     #EXT-X-PLAYLIST-TYPE:VOD
     #EXT-X-TARGETDURATION:18
     #EXT-X-MEDIA-SEQUENCE:0
     #EXTINF:4,
     0.ts
     #EXTINF:8,
     1.ts
     #EXTINF:8,
     2.ts
     #EXTINF:10,
     3.ts
     #EXTINF:13,
     4.ts
     #EXTINF:18,
     5.ts
     #EXTINF:12,
     6.ts
     #EXTINF:12,
     7.ts
     #EXT-X-ENDLIST
     */
//    NSString *dataStr = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://asp.cntv.lxdns.com/asp/hls/main/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/main.m3u8?maxbr=850"] encoding:NSUTF8StringEncoding error:nil];
    
    /*!
     #EXTM3U
     #EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=460800, RESOLUTION=480x360
     /asp/hls/450/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/450.m3u8
     */
    
//    NSLog(@"%@", dataStr);
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



/*!
 *  测试模型(测试数据库保存) */
@synthesize xiaoMing = _xiaoMing;
@synthesize video = _video;

- (SJUser *)xiaoMing {
    if ( _xiaoMing ) return _xiaoMing;
    _xiaoMing = [SJUser new];
    _xiaoMing.userId = 12313;
    _xiaoMing.name = @"小明";
    _xiaoMing.downloadedVideos = @[self.video].mutableCopy;
    return _xiaoMing;
}

- (SJVideoInfo *)video {
    if ( _video ) return _video;
    _video = [SJVideoInfo new];
    _video.name = @"某小偷上公交车偷钱包";
    _video.remoteURLStr = @"http://asp.cntv.lxdns.com/asp/hls/main/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/main.m3u8?maxbr=850";
    _video.videoId = 1123;
    return _video;
}

@end

//
//  ViewController.m
//  SJM3U8DownloadProject
//
//  Created by 畅三江 on 2017/10/3.
//  Copyright © 2017年 畅三江. All rights reserved.
//

#import "ViewController.h"
#import "SJDownloadServer.h"

@interface ViewController ()

@end

@implementation ViewController

- (IBAction)clickedDoanload:(id)sender {
    [[SJDownloadServer sharedServer] downloadWithURLStr:@"http://asp.cntv.lxdns.com/asp/hls/main/0303000a/3/default/f8c28211-dcc2-11e4-9584-21fa84a4ab6e/main.m3u8?maxbr=850" downloadMode:SJDownloadMode450 downloadProgress:^(float progress) {
        
    } completion:^(NSString *dataPath) {
        
    } errorBlock:^(NSError *error) {
        NSLog(@"%@", error.userInfo[SJDownloadErrorInfoKey]);
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


@end

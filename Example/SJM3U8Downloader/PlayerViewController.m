//
//  PlayerViewController.m
//  SJM3U8Downloader_Example
//
//  Created by BlueDancer on 2019/12/23.
//  Copyright © 2019 changsanjiang@gmail.com. All rights reserved.
//

#import "PlayerViewController.h"
//#import <SJVideoPlayer/SJVideoPlayer.h>
//#import <Masonry/Masonry.h>

@interface PlayerViewController ()
//@property (nonatomic, strong, readonly) SJVideoPlayer *player;
@end

@implementation PlayerViewController

- (instancetype)initWithUrl:(NSString *)url {
    self = [super init];
    if ( self ) {
//        _player = SJVideoPlayer.player;
//        _player.assetURL = [NSURL URLWithString:url];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

//    [self.view addSubview:_player.view];
//    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.offset(0);
//    }];
    // Do any additional setup after loading the view.
}

@end

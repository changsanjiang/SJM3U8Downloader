//
//  PlayerViewController.m
//  SJM3U8Downloader_Example
//
//  Created by BlueDancer on 2019/12/23.
//  Copyright © 2019 changsanjiang@gmail.com. All rights reserved.
//

#import "PlayerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface PlayerViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation PlayerViewController

- (instancetype)initWithUrl:(NSString *)url {
    self = [super init];
    if ( self ) {
        _player = [AVPlayer playerWithURL:[NSURL URLWithString:url]];
        [_player play];
    }
    return self;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    
    _playerLayer = AVPlayerLayer.layer;
    _playerLayer.player = _player;
    [self.view.layer addSublayer:_playerLayer];
    
    // Do any additional setup after loading the view.
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _playerLayer.frame = self.view.bounds;
}
@end

//
//  TestListViewController.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/19.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "TestListViewController.h"
#import "SJM3U8DownloadListController.h"
#import "TestItemTableViewCell.h"
#import <SJUIKit/NSAttributedString+SJMake.h>
#import "PlayerViewController.h"

NS_ASSUME_NONNULL_BEGIN
@interface TestListViewController ()<SJM3U8DownloadListControllerDelegate, SJM3U8DownloadListItemDelegate>

@end

@implementation TestListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [TestItemTableViewCell registerWithTableView:self.tableView];
    
    SJM3U8DownloadListController.shared.delegate = self;
    
    self.tableView.rowHeight = 120;
    
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem.alloc initWithTitle:@"Resume" style:UIBarButtonItemStylePlain target:self action:@selector(resume)];
    
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem.alloc initWithTitle:@"Suspend" style:UIBarButtonItemStylePlain target:self action:@selector(suspend)];
    
    for ( id<SJM3U8DownloadListItem> item in SJM3U8DownloadListController.shared.items ) {
        item.delegate = self;
    }
}

- (void)resume {
    if ( SJM3U8DownloadListController.shared.count == 0 ) {
        NSArray<NSString *> *urls =
 @[@"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8"
        ];
        
        for ( NSString *url in urls ) {
            [SJM3U8DownloadListController.shared addItemWithUrl:url];
        }
    }
    else {
        [SJM3U8DownloadListController.shared resumeAllItems];
    }
    
    for ( id<SJM3U8DownloadListItem> item in SJM3U8DownloadListController.shared.items ) {
        item.delegate = self;
    }
    [self.tableView reloadData];
}

- (void)suspend {
    [SJM3U8DownloadListController.shared suspendAllItems];
}

- (void)listController:(id<SJM3U8DownloadListController>)controller itemsDidChange:(NSArray<id<SJM3U8DownloadListItem>> *)items {
    [self.tableView reloadData];
}

- (void)downloadItemProgressDidChange:(id<SJM3U8DownloadListItem>)item {
    NSInteger idx = [SJM3U8DownloadListController.shared indexOfItemByUrl:item.url];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
    [self _updateContentForCell:[self.tableView cellForRowAtIndexPath:indexPath] forRowAtIndexPath:indexPath];
}

- (void)downloadItemStateDidChange:(id<SJM3U8DownloadListItem>)item {
    NSInteger idx = [SJM3U8DownloadListController.shared indexOfItemByUrl:item.url];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
    [self _updateContentForCell:[self.tableView cellForRowAtIndexPath:indexPath] forRowAtIndexPath:indexPath];
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return SJM3U8DownloadListController.shared.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [TestItemTableViewCell cellWithTableView:tableView indexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(TestItemTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self _updateContentForCell:cell forRowAtIndexPath:indexPath];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewRowAction *action = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [SJM3U8DownloadListController.shared deleteItemAtIndex:indexPath.row];
    }];
    return @[action];
}

#pragma mark -

- (void)_updateContentForCell:(TestItemTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    id<SJM3U8DownloadListItem> item = [SJM3U8DownloadListController.shared itemAtIndex:indexPath.row];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.attributedText = [NSAttributedString sj_UIKitText:^(id<SJUIKitTextMakerProtocol>  _Nonnull make) {
        make.append([NSString stringWithFormat:@"%lu", (unsigned long)[item.url hash]]);
        make.append(@"\n");
        make.append([NSString stringWithFormat:@"%.02f%%", item.progress * 100]);
        make.append(@"\n");
        make.append([NSString stringWithFormat:@"%.02lfm/s", item.state == SJDownloadStateFinished ? 0 : item.speed]);
        make.append(@"\n");
        make.textColor(UIColor.blackColor);
        
        NSString *state = nil;
        switch ( item.state ) {
            case SJDownloadStateWaiting:
                state = @"state: Waiting";
                break;
            case SJDownloadStateSuspended:
                state = @"state: Suspended";
                break;
            case SJDownloadStateRunning:
                state = @"state: Running";
                break;
            case SJDownloadStateCancelled:
                state = @"state: Cancelled";
                break;
            case SJDownloadStateFinished: {
                state = @"state: Finished";
                if ( self.presentingViewController == nil ) {
//                    http://hls.cntv.myalicdn.com/asp/hls/1200/0303000a/3/default/62d3dbaef5df4bfea6f44608d93a3f61/1200.m3u8
                    
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        NSString *url = [SJM3U8DownloadListController.shared localPlayUrlByUrl:item.url];
                        PlayerViewController *vc = [PlayerViewController.alloc initWithUrl:url];
                        [self presentViewController:vc animated:YES completion:nil];
                    });
                }
            }
                break;
            case SJDownloadStateFailed:
                state = @"state: Failed";
                break;
        }
        make.append(state);
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<SJM3U8DownloadListItem> item = [SJM3U8DownloadListController.shared itemAtIndex:indexPath.row];
    switch ( item.state ) {
        case SJDownloadStateWaiting:
        case SJDownloadStateRunning: {
            [SJM3U8DownloadListController.shared suspendItemAtIndex:indexPath.row];
        }
            break;
        case SJDownloadStateSuspended:
        case SJDownloadStateFailed: {
            [SJM3U8DownloadListController.shared resumeItemAtIndex:indexPath.row];
        }
            break;
        case SJDownloadStateCancelled:
        case SJDownloadStateFinished:
            break;
    }
}
@end
NS_ASSUME_NONNULL_END

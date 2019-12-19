//
//  SJM3U8DownloadListController.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/18.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8DownloadListController.h"
#import <SJUIKit/SJSQLite3.h>
#import <SJUIKit/SJSQLite3+QueryExtended.h>
#import "SJM3U8DownloadListItem.h"
#import "SJM3U8DownloadListOperation.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8DownloadListController ()<SJM3U8DownloadListOperationDelegate>
@property (nonatomic, strong, readonly) NSOperationQueue *operationQueue;
@property (nonatomic, strong, readonly) NSMutableArray<SJM3U8DownloadListItem *> *listItems;
@property (nonatomic, strong, readonly) SJSQLite3 *database;
@property (nonatomic, strong, readonly) SJM3U8Downloader *downloader;
@end

@implementation SJM3U8DownloadListController
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = self.new;
    });
    return obj;
}

- (instancetype)initWithDownloader:(SJM3U8Downloader *)downloader {
    self = [super init];
    if ( self ) {
        _downloader = downloader;
         NSString *databasePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"sjlist.db"];
        _database = [SJSQLite3.alloc initWithDatabasePath:databasePath];
        NSArray<SJM3U8DownloadListItem *> *_Nullable items = [_database objectsForClass:SJM3U8DownloadListItem.class conditions:nil orderBy:nil error:NULL];
        for ( SJM3U8DownloadListItem *listItem in items ) {
            if ( listItem.state == SJDownloadStateWaiting ||
                 listItem.state == SJDownloadStateRunning ) {
                listItem.state = SJDownloadStateSuspended;
                [_database update:listItem forKey:@"state" error:NULL];
            }
        }
        _listItems = items ? items.mutableCopy : NSMutableArray.array;
        _operationQueue = NSOperationQueue.alloc.init;
        _operationQueue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (instancetype)init {
    return [self initWithDownloader:SJM3U8Downloader.shared];
}

#pragma mark -

- (NSString *)localPlayUrlByUrl:(NSString *)url {
    return [self.downloader localPlayUrlByUrl:url];
}

- (NSString *)localPlayUrlByFolderName:(NSString *)name {
    return [self.downloader localPlayUrlByFolderName:name];
}

- (nullable NSArray<id<SJM3U8DownloadListItem>> *)items {
    return _listItems.count > 0 ? _listItems.copy : nil;
}

- (NSInteger)count {
    return _listItems.count;
}

#pragma mark -

- (void)setMaxConcurrentDownloadCount:(NSUInteger)maxConcurrentDownloadCount {
    _operationQueue.maxConcurrentOperationCount = maxConcurrentDownloadCount;
}

- (NSUInteger)maxConcurrentDownloadCount {
    return _operationQueue.maxConcurrentOperationCount;
}

#pragma mark -

- (nullable id<SJM3U8DownloadListItem>)itemAtIndex:(NSInteger)idx {
    __auto_type items = self.listItems;
    if ( idx < items.count && idx >= 0 ){
        return items[idx];
    }
    return nil;
}
- (nullable id<SJM3U8DownloadListItem>)itemByUrl:(NSString *)url {
    for ( id<SJM3U8DownloadListItem> item in self.listItems ) {
        if ( [item.url isEqualToString:url] )
            return item;
    }
    return nil;
}
- (nullable id<SJM3U8DownloadListItem>)itemByFolderName:(NSString *)name {
    for ( id<SJM3U8DownloadListItem> item in self.listItems ) {
        if ( [item.folderName isEqualToString:name] )
            return item;
    }
    return nil;
}
- (NSInteger)indexOfItemByUrl:(NSString *)url {
    __auto_type items = self.listItems;
    for ( NSInteger i = 0 ; i < items.count ; ++ i ) {
        id<SJM3U8DownloadListItem> item = items[i];
        if ( [item.url isEqualToString:url] )
            return i;
    }
    return NSNotFound;
}
- (NSInteger)indexOfItemByFolderName:(NSString *)name {
    __auto_type items = self.listItems;
    for ( NSInteger i = 0 ; i < items.count ; ++ i ) {
        id<SJM3U8DownloadListItem> item = items[i];
        if ( [item.folderName isEqualToString:name] )
            return i;
    }
    return NSNotFound;
}

- (void)resumeItemAtIndex:(NSInteger)index {
    SJM3U8DownloadListItem *_Nullable listItem = (id)[self itemAtIndex:index];
    if ( listItem != nil ) {
        if ( listItem.operation == nil ||
             listItem.operation.isCancelled ||
             listItem.operation.isFinished ) {
            ///
            /// 将在调用暂停时, 移除操作对象, 此时需重新创建新的操作对象
            ///
            listItem.operation = [SJM3U8DownloadListOperation.alloc initWithUrl:listItem.url folderName:listItem.folderName downloader:self.downloader delegate:self];
            [self.operationQueue addOperation:listItem.operation];
            listItem.state = SJDownloadStateWaiting;
            [self.database update:listItem forKey:@"state" error:NULL];
        }
    }
}
- (void)resumeItemByUrl:(NSString *)url {
    [self resumeItemAtIndex:[self indexOfItemByUrl:url]];
}
- (void)resumeItemByFolderName:(NSString *)name {
    [self resumeItemAtIndex:[self indexOfItemByFolderName:name]];
}
- (void)resumeAllItems {
    for ( NSInteger i = 0 ; i < self.listItems.count ; ++ i ) {
        [self resumeItemAtIndex:i];
    }
}

- (void)suspendItemAtIndex:(NSInteger)index {
    SJM3U8DownloadListItem *_Nullable listItem = (id)[self itemAtIndex:index];
    if ( listItem != nil ) {
        ///
        /// 暂停时, 移除操作对象
        ///
        [listItem.operation cancelOperation];
        listItem.operation = nil;
        listItem.state = SJDownloadStateSuspended;
        [self.database update:listItem forKey:@"state" error:NULL];
    }
}
- (void)suspendItemByUrl:(NSString *)url {
    [self suspendItemAtIndex:[self indexOfItemByUrl:url]];
}
- (void)suspendItemByFolderName:(NSString *)name {
    [self suspendItemAtIndex:[self indexOfItemByFolderName:name]];
}
- (void)suspendAllItems {
    for ( NSInteger i = 0 ; i < self.listItems.count ; ++ i ) {
        [self suspendItemAtIndex:i];
    }
}

- (NSInteger)addItemWithUrl:(NSString *)url {
    return [self addItemWithUrl:url folderName:nil];
}

- (NSInteger)addItemWithUrl:(NSString *)url folderName:(nullable NSString *)name {
    if ( url.length != 0 ) {
        NSInteger idx = (name.length == 0 ? [self indexOfItemByUrl:url] : [self indexOfItemByFolderName:name]);
        if ( idx == NSNotFound ) {
            SJM3U8DownloadListItem *listItem = [SJM3U8DownloadListItem.alloc initWithUrl:url folderName:name];
            [self.listItems addObject:listItem];
            [self.database save:listItem error:NULL];
            
            listItem.operation = [SJM3U8DownloadListOperation.alloc initWithUrl:url folderName:name downloader:self.downloader delegate:self];
            [self.operationQueue addOperation:listItem.operation];
            idx = self.listItems.count - 1;
            [self _itemsDidChange];
        }
        return idx;
    }
    return NSNotFound;
}

- (void)updateContentsForItemAtIndex:(NSInteger)idx {
    SJM3U8DownloadListItem *_Nullable listItem = (id)[self itemAtIndex:idx];
    if ( listItem != nil ) {
        [self.database save:listItem error:NULL];
    }
}
- (void)updateContentsForItemByUrl:(NSString *)url {
    [self updateContentsForItemAtIndex:[self indexOfItemByUrl:url]];
}
- (void)updateContentsForItemByFolderName:(NSString *)name {
    [self updateContentsForItemAtIndex:[self indexOfItemByFolderName:name]];
}

- (void)deleteItemAtIndex:(NSInteger)index {
    SJM3U8DownloadListItem *_Nullable listItem = (id)[self itemAtIndex:index];
    if ( listItem != nil ) {
        if ( listItem.operation != nil ) {
            [listItem.operation cancelOperation];
            listItem.operation = nil;
        }
        
        listItem.state = SJDownloadStateCancelled;
        [self.downloader deleteWithUrl:listItem.url];
        [self.listItems removeObjectAtIndex:index];
        [self.database removeObjectForClass:SJM3U8DownloadListItem.class primaryKeyValue:@(listItem.id) error:NULL];
        [self _itemsDidChange];
    }
}
- (void)deleteItemForUrl:(NSString *)url {
    [self deleteItemAtIndex:[self indexOfItemByUrl:url]];
}
- (void)deleteItemForFolderName:(NSString *)name {
    [self deleteItemAtIndex:[self indexOfItemByFolderName:name]];
}
- (void)deleteAllItems {
    for ( NSInteger i = self.listItems.count - 1; i >= 0 ; -- i ) {
        [self deleteItemAtIndex:i];
    }
}

#pragma mark -

- (void)operationDidStart:(SJM3U8DownloadListOperation *)operation {
    if ( operation.isCancelled || operation.isFinished ) return;
    SJM3U8DownloadListItem *listItem = (id)[self itemByUrl:operation.url];
    listItem.state = SJDownloadStateRunning;
    [self.database update:listItem forKey:@"state" error:NULL];
}

- (void)operation:(SJM3U8DownloadListOperation *)operation didComplete:(BOOL)isFinished {
    NSInteger idx = [self indexOfItemByUrl:operation.url];
    if ( idx != NSNotFound ) {
        SJM3U8DownloadListItem *listItem = (id)[self itemAtIndex:idx];
        listItem.state = isFinished ? SJDownloadStateFinished : SJDownloadStateFailed;
        [operation finishedOperation];
        
        /// 下载完成后, 从队列移除
        if ( isFinished ) {
            [self.database removeObjectForClass:listItem.class primaryKeyValue:@(listItem.id) error:NULL];
            [self.listItems removeObjectAtIndex:idx];
            [self _itemsDidChange];
        }
    }
}

- (void)progressDidChangeForOperation:(SJM3U8DownloadListOperation *)operation {
    SJM3U8DownloadListItem *listItem = (id)[self itemByUrl:operation.url];
    listItem.progress = operation.progress;
    double kb = operation.speed * 1.0 / 1024;
    double m = kb / 1024 / operation.periodicTimeInterval;
    listItem.speed = m;
}

#pragma mark -

- (void)_itemsDidChange {
    if ( [self.delegate respondsToSelector:@selector(listController:itemsDidChange:)] ) {
        [self.delegate listController:self itemsDidChange:self.items];
    }
}
@end
NS_ASSUME_NONNULL_END

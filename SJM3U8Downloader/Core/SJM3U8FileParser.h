//
//  SJM3U8FileParser.h
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SJM3U8FileParser : NSObject
+ (nullable instancetype)fileParserWithURL:(NSString *)url saveKeyToFolder:(NSString *)folder error:(NSError **)error;
+ (nullable instancetype)fileParserWithContentsOfFile:(NSString *)path error:(NSError **)error;

///
/// 原始地址
///
@property (nonatomic, copy, readonly) NSString *url;

///
/// 每个ts的url数组
///
@property (nonatomic, copy, readonly) NSArray<NSString *> *tsArray;

///
/// 重组过的contents
///
@property (nonatomic, copy, readonly) NSString *contents;

- (void)writeToFile:(NSString *)path error:(NSError **)error;
 
- (void)writeContentsToFile:(NSString *)path error:(NSError **)error;

- (nullable NSString *)TSFilenameAtIndex:(NSInteger)idx;
@end
NS_ASSUME_NONNULL_END

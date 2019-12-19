//
//  SJM3U8FileParser.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8FileParser.h"

NS_ASSUME_NONNULL_BEGIN
#define SJM3U8FileParseError [NSError errorWithDomain:NSCocoaErrorDomain code:3000 userInfo:@{@"msg":@"解析文件失败"}];


@interface NSString (SJM3U8FileParserExtended)
- (nullable NSArray<NSValue *> *)sj_rangesByMatchingPattern:(NSString *)pattern;
- (nullable NSString *)sj_filename;
@end

@implementation NSString (SJM3U8FileParserExtended)
- (nullable NSArray<NSValue *> *)sj_rangesByMatchingPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    [regex enumerateMatchesInString:self options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if ( result != nil ) {
            [m addObject:[NSValue valueWithRange:result.range]];
        }
    }];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSString *)sj_filename {
    NSString *component = self.lastPathComponent;
    NSRange range = [component rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        return [component substringToIndex:range.location];
    }
    return component;
}
@end

@interface SJM3U8FileParser ()
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy, nullable) NSArray<NSString *> *tsArray;
@property (nonatomic, copy, nullable) NSString *contents;
@end

@implementation SJM3U8FileParser
+ (nullable instancetype)fileParserWithURL:(NSString *)url saveKeyToFolder:(NSString *)folder error:(NSError **)error {
    NSString *_Nullable contents = nil;
    NSString *_Nullable redirect = nil;
    NSArray<NSString *> *_Nullable tsArray = nil;
    NSError *_Nullable inner_error = nil;
    NSString *cur = url;
    do {
        contents = [NSString stringWithContentsOfURL:[NSURL URLWithString:cur] encoding:0 error:&inner_error];
        if ( contents == nil ) {
            break;
        }
        
        ///
        /// 是否重定向
        ///
        redirect = [self _urlsWithPattern:@"(?:.*\\.m3u8[^\\s]*)" url:cur contents:contents].firstObject;
        if ( redirect != nil ) {
            cur = redirect;
        }
        else {
            
            ///
            /// 解析ts地址
            ///
            tsArray = [self _urlsWithPattern:@"(?:.*\\.ts[^\\s]*)" url:cur contents:contents];
            break;
        }
    } while (1);
    
    if ( inner_error != nil ) {
        if ( error != NULL )  *error = inner_error;
        return nil;
    }
    
    if ( tsArray == nil ) {
        if ( error != NULL ) *error = SJM3U8FileParseError;
        return nil;
    }
    
    NSString *restructureContents = [self _restructureContents:contents saveKeyToFolder:folder error:&inner_error];
    if ( restructureContents.length == 0 ) {
        if ( error != NULL )  *error = inner_error;
        return nil;
    }
    
    SJM3U8FileParser *parser = SJM3U8FileParser.alloc.init;
    parser.url = url;
    parser.tsArray = tsArray;
    parser.contents = restructureContents;
    return parser;
}

+ (nullable instancetype)fileParserWithContentsOfFile:(NSString *)path error:(NSError **)error {
    if ( path.length == 0 )
        return nil;
    
    NSError *inner_error = nil;
    NSDictionary *info = nil;
    if (@available(iOS 11.0, *)) {
        info = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:&inner_error];
    } else {
        info = [NSDictionary dictionaryWithContentsOfFile:path];
        if ( info == nil ) inner_error = SJM3U8FileParseError;
    }
    
    if ( inner_error != nil ) {
        if ( error != NULL )  *error = inner_error;
        return nil;
    }
    SJM3U8FileParser *fileParser = SJM3U8FileParser.alloc.init;
    fileParser.url = info[@"url"];
    fileParser.tsArray = info[@"tsArray"];
    fileParser.contents = info[@"contents"];
    return fileParser;
}

+ (nullable NSArray<NSString *> *)_urlsWithPattern:(NSString *)pattern url:(NSString *)url contents:(NSString *)contents {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[contents sj_rangesByMatchingPattern:pattern] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *matched = [contents substringWithRange:[range rangeValue]];
        NSString *matchedUrl = nil;
        if ( [matched containsString:@"://"] ) {
            matchedUrl = matched;
        }
        else if ( [matched hasPrefix:@"/"] ) {
            NSURL *URL = [NSURL URLWithString:url];
            matchedUrl = [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, matched];
        }
        else {
            matchedUrl = [NSString stringWithFormat:@"%@/%@", url.stringByDeletingLastPathComponent, matched];
        }
        [m addObject:matchedUrl];
    }];
    
    return m.count != 0 ? m.copy : nil;
}

+ (nullable NSString *)_restructureContents:(NSString *)contents saveKeyToFolder:(NSString *)folder error:(NSError **)error {
    NSMutableString *m = contents.mutableCopy;
    [[contents sj_rangesByMatchingPattern:@"(?:.*\\.ts[^\\s]*)"] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSString *filename = matched.sj_filename;
        [m replaceCharactersInRange:rangeValue withString:filename];
    }];
    
    __block NSError *inner_error = nil;
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[m sj_rangesByMatchingPattern:@"#EXT-X-KEY:METHOD=AES-128,URI=\".*\""] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSInteger URILocation = [matched rangeOfString:@"\""].location + 1;
        NSRange URIRange = NSMakeRange(URILocation, matched.length-URILocation-1);
        NSString *URI = [matched substringWithRange:URIRange];
        NSData *keyData = [NSData dataWithContentsOfURL:[NSURL URLWithString:URI] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        [keyData writeToFile:[folder stringByAppendingPathComponent:URI.sj_filename] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *reset = [matched stringByReplacingCharactersInRange:URIRange withString:URI.sj_filename];
        [m replaceCharactersInRange:rangeValue withString:reset];
    }];
    
    if ( inner_error != nil ) {
        if ( error != NULL ) *error = inner_error;
        return nil;
    }
    return m.copy;
}

- (void)writeToFile:(NSString *)path error:(NSError **)error {
    if ( path.length != 0 ) {
        NSMutableDictionary *info = NSMutableDictionary.dictionary;
        info[@"url"] = self.url;
        info[@"tsArray"] = self.tsArray;
        info[@"contents"] = self.contents;
        if (@available(iOS 11.0, *)) {
            [info writeToURL:[NSURL fileURLWithPath:path] error:error];
        } else {
            [info writeToFile:path atomically:NO];
        }
    }
}

- (void)writeContentsToFile:(NSString *)path error:(NSError **)error {
    if ( path.length != 0 ) {
        [self.contents writeToURL:[NSURL fileURLWithPath:path] atomically:NO encoding:NSUTF8StringEncoding error:error];
    }
}

- (nullable NSString *)tsfilenameAtIndex:(NSInteger)idx {
    if ( idx < self.tsArray.count && idx >= 0 ) {
        return self.tsArray[idx].sj_filename;
    }
    return nil;
}
@end
NS_ASSUME_NONNULL_END


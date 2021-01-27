//
//  SJM3U8FileParser.m
//  SJM3u8Downloader
//
//  Created by BlueDancer on 2019/12/16.
//  Copyright © 2019 SanJiang. All rights reserved.
//

#import "SJM3U8FileParser.h"
#import "SJM3U8Data.h"

NS_ASSUME_NONNULL_BEGIN
#define SJM3U8FileParseError() [NSError errorWithDomain:NSCocoaErrorDomain code:3000 userInfo:@{@"msg":@"解析文件失败"}];
 

// https://tools.ietf.org/html/rfc8216

#define HLS_FORMAT_FIRST_LINE_TAG           @"#EXTM3U"
     
#define HLS_REGEX_INDEX                     @".*\\.m3u8[^\\s]*"
#define HLS_REGEX_INDEX_2                   @"#EXT-X-STREAM-INF.+\\s(.+)\\s"
#define HLS_REGEX_TS                        @"#EXTINF.+\\s(.+)\\s"
#define HLS_REGEX_AESKEY                    @"#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\""
#define HLS_REGEX_LOCAL_URIs                @"(.*\\.ts[^\\s]*)|(#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\")"

#define HLS_INDEX_TS        1
#define HLS_INDEX_AESKEY    1
#define HLS_INDEX_INDEX_2   1

#define HLS_SUFFIX_TS       @".ts"
#define HLS_SUFFIX_AESKEY   @".key"

@interface NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)m3u_rangesByMatchingPattern:(NSString *)pattern;
- (nullable NSArray<NSTextCheckingResult *> *)m3u_textCheckingResultsByMatchPattern:(NSString *)pattern;
- (nullable NSString *)m3u_filenameWithSuffix:(NSString *)suffix;
@end

@interface NSString (MCSHLSContents)
- (nullable NSArray<NSString *> *)m3u_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL;
- (nullable NSArray<NSString *> *)m3u_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL;
- (NSString *)m3u_convertToUrlByContentsURL:(NSURL *)contentsURL;
@end

@interface SJM3U8FileParser ()
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy, nullable) NSArray<NSString *> *tsArray;
@property (nonatomic, copy, nullable) NSString *contents;
@end

@implementation SJM3U8FileParser
+ (nullable instancetype)fileParserWithURL:(NSString *)url saveKeyToFolder:(NSString *)folder error:(NSError **)error {
    __block NSURLRequest *curr = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSString *_Nullable contents = nil;
    do {
        NSError *downloadError = nil;
        NSData *data = [SJM3U8Data dataWithContentsOfRequest:curr networkTaskPriority:1 error:&downloadError willPerformHTTPRedirection:^(NSHTTPURLResponse * _Nonnull response, NSURLRequest * _Nonnull newRequest) {
            curr = newRequest;
        }];
        
        if ( downloadError != nil ) {
            if ( error != NULL ) *error = SJM3U8FileParseError();
            return nil;
        }
        
        contents = [NSString.alloc initWithData:data encoding:0];
        if ( contents == nil )
            break;

        // 是否重定向
        // 是否重定向
        NSString *next = [self _indexUrlForContents:contents contentsURL:curr.URL];
        if ( next == nil ) break;

        curr = [NSURLRequest requestWithURL:[NSURL URLWithString:next]];
    } while ( true );
    
    if ( contents == nil || ![contents hasPrefix:HLS_FORMAT_FIRST_LINE_TAG] ) {
        if ( error != NULL ) *error = SJM3U8FileParseError();
        return nil;
    }

    ///
    /// #EXTINF:10,
    /// 000000.ts
    ///
    NSArray<NSTextCheckingResult *> *tsResults = [contents m3u_textCheckingResultsByMatchPattern:HLS_REGEX_TS];
    if ( tsResults.count == 0 ) {
        if ( error != NULL ) *error = SJM3U8FileParseError();
        return nil;
    }
    
    __block NSError *inner_error = nil;
    NSMutableString *restructureContents = contents.mutableCopy;
    NSMutableArray<NSString *> *_Nullable tsArray = NSMutableArray.array;
    [tsResults enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [result rangeAtIndex:HLS_INDEX_TS];
        NSString *matched = [contents substringWithRange:range];
        // ts url
        NSString *url = [matched m3u_convertToUrlByContentsURL:curr.URL];
        [tsArray addObject:url];
        
        // restructureContents
        NSString *filename = [matched m3u_filenameWithSuffix:HLS_SUFFIX_TS];
        [restructureContents replaceCharactersInRange:range withString:filename];
    }];
    
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[restructureContents m3u_textCheckingResultsByMatchPattern:HLS_REGEX_AESKEY] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange URIRange = [result rangeAtIndex:HLS_INDEX_AESKEY];
        // AESKEY
        NSString *URI = [restructureContents substringWithRange:URIRange];
        NSString *url = [URI m3u_convertToUrlByContentsURL:curr.URL];
        NSData *keyData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *filename = [URI m3u_filenameWithSuffix:HLS_SUFFIX_AESKEY];
        [keyData writeToFile:[folder stringByAppendingPathComponent:filename] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        
        // restructureContents
        [restructureContents replaceCharactersInRange:URIRange withString:filename];
    }];
    
    if ( inner_error != nil ) {
        if ( error != NULL )  *error = inner_error;
        return nil;
    }
    
    SJM3U8FileParser *parser = SJM3U8FileParser.alloc.init;
    parser.url = url;
    parser.tsArray = [tsArray reverseObjectEnumerator].allObjects;
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
        if ( info == nil ) inner_error = SJM3U8FileParseError();
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

- (nullable NSString *)TSFilenameAtIndex:(NSInteger)idx {
    if ( idx < self.tsArray.count && idx >= 0 ) {
        return [self.tsArray[idx] m3u_filenameWithSuffix:HLS_SUFFIX_TS];
    }
    return nil;
}

+ (nullable NSString *)_indexUrlForContents:(NSString *)contents contentsURL:(NSURL *)contentsURL {
    // 是否重定向
    // 1
    NSString *redirectUrl = [contents m3u_urlsByMatchingPattern:HLS_REGEX_INDEX contentsURL:contentsURL].firstObject;
    // 2
    if ( redirectUrl == nil ) {
        redirectUrl = [contents m3u_urlsByMatchingPattern:HLS_REGEX_INDEX_2 atIndex:HLS_INDEX_INDEX_2 contentsURL:contentsURL].firstObject;
    }
    return redirectUrl;
}
@end



@implementation NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)m3u_rangesByMatchingPattern:(NSString *)pattern {
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    for ( NSTextCheckingResult *result in [self m3u_textCheckingResultsByMatchPattern:pattern])
        [m addObject:[NSValue valueWithRange:result.range]];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSArray<NSTextCheckingResult *> *)m3u_textCheckingResultsByMatchPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
    NSMutableArray<NSTextCheckingResult *> *m = NSMutableArray.array;
    [regex enumerateMatchesInString:self options:kNilOptions range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if ( result != nil ) {
            [m addObject:result];
        }
    }];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSString *)m3u_filenameWithSuffix:(NSString *)suffix {
    NSString *filename = self.lastPathComponent;
    NSRange range = [filename rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        return [filename substringToIndex:range.location];
    }
    if ( ![filename hasSuffix:suffix] )
        filename = [NSString stringWithFormat:@"%@%@", filename, suffix];
    return filename;
}
@end

@implementation NSString (MCSHLSContents)
- (nullable NSArray<NSString *> *)m3u_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL {
    return [self m3u_urlsByMatchingPattern:pattern atIndex:0 contentsURL:contentsURL];
}

- (nullable NSArray<NSString *> *)m3u_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[self m3u_textCheckingResultsByMatchPattern:pattern] enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        The range at index 0 always matches the range property.  Additional ranges, if any, will have indexes from 1 to numberOfRanges-1. rangeWithName: can be used with named regular expression capture groups
        NSRange range = [obj rangeAtIndex:index];
        NSString *matched = [self substringWithRange:range];
        NSString *url = [matched m3u_convertToUrlByContentsURL:contentsURL];
        [m addObject:url];
    }];
    return m.count != 0 ? m.copy : nil;
}

/// 将路径转换为url
- (NSString *)m3u_convertToUrlByContentsURL:(NSURL *)URL {
    static NSString *const HLS_PREFIX_LOCALHOST = @"http://localhost";
    static NSString *const HLS_PREFIX_PATH = @"/";
    
    NSString *url = nil;
    if ( [self hasPrefix:HLS_PREFIX_PATH] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, self];
    }
    else if ( [self hasPrefix:HLS_PREFIX_LOCALHOST] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, [self substringFromIndex:HLS_PREFIX_LOCALHOST.length]];
    }
    else if ( [self containsString:@"://"] ) {
        url = self;
    }
    else {
        url = [NSString stringWithFormat:@"%@/%@", URL.absoluteString.stringByDeletingLastPathComponent, self];
    }
    return url;
}
@end
NS_ASSUME_NONNULL_END

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "SJDownloadDataTask.h"
#import "NSTimer+SJDownloadDataTaskAdd.h"
#import "SJOutPutStream.h"
#import "SJURLSessionDataTaskServer.h"
#import "SJDownloadDataTaskResourceLoader.h"

FOUNDATION_EXPORT double SJDownloadDataTaskVersionNumber;
FOUNDATION_EXPORT const unsigned char SJDownloadDataTaskVersionString[];


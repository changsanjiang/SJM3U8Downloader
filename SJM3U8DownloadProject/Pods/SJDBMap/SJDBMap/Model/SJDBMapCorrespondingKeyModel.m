//
//  SJDBMapCorrespondingKeyModel.m
//  SJProject
//
//  Created by BlueDancer on 2017/6/3.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import "SJDBMapCorrespondingKeyModel.h"

#ifdef __SJDBug
#import <YYKit.h>
#endif

@implementation SJDBMapCorrespondingKeyModel

+ (NSString *)autoincrementPrimaryKey {
    return @"cKMID";
}


#ifdef __SJDBug
- (NSString *)description {
    return [self modelDescription];
}
#endif
@end

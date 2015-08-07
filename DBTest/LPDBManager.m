//
//  LPDBManager.m
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import "LPDBManager.h"

@implementation LPDBManager

+ (NSString *)databasePath;
{
    NSString* strPath =  [[NSBundle mainBundle] bundlePath];
    NSString *documentsDirectory;
    if ([strPath hasPrefix:@"/var/mobile/Applications"]) {
        NSRange range = [strPath rangeOfString:@"/" options:NSBackwardsSearch];
        strPath = [strPath substringToIndex:range.location];
        documentsDirectory = [strPath stringByAppendingFormat:@"/Documents"];
    }else {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        documentsDirectory = [paths objectAtIndex:0];
    }
    return [documentsDirectory stringByAppendingPathComponent: @"db.db"];
}

+ (LPDBManager *)shareManager
{
    static LPDBManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (manager == nil) {
            manager = [[LPDBManager alloc] init];
        }
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        _queue = [FMDatabaseQueue databaseQueueWithPath: [[self class] databasePath]];
    }
    return self;
}
@end

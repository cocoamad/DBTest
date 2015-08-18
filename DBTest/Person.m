//
//  Person.m
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import "Person.h"
@implementation Person
- (instancetype)init
{
    if (self = [super init]) {
        _age = 0;
        _sex = NO;
        _name = @"";
        _hight = 0;
        _nickName = @"";
        _level = 0;
    }
    return self;
}
@end

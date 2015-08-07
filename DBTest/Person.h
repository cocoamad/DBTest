//
//  Person.h
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LPDBModel.h"

@interface Person : LPDBModel
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) BOOL sex;
@property (nonatomic, assign) float hight;

@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, assign) NSInteger level;

@end

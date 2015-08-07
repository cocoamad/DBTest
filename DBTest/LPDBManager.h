//
//  LPDBManager.h
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabaseAdditions.h"

@interface LPDBManager : NSObject {

}
@property (nonatomic,readonly) FMDatabaseQueue* queue;

+ (LPDBManager *)shareManager;
@end

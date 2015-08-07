//
//  LPDBModel.h
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import <Foundation/Foundation.h>

#define isCollectionType(x) (isNSSetType(x) || isNSArrayType(x) || isNSDictionaryType(x))
#define isNSArrayType(x) ([x isEqualToString:@"NSArray"] || [x isEqualToString:@"NSMutableArray"])
#define isNSDictionaryType(x) ([x isEqualToString:@"NSDictionary"] || [x isEqualToString:@"NSMutableDictionary"])
#define isNSSetType(x) ([x isEqualToString:@"NSSet"] || [x isEqualToString:@"NSMutableSet"])

#define isIntegerType(x) ([x isEqualToString:@"i"] || [x isEqualToString:@"I"] || [x isEqualToString:@"l"] || [x isEqualToString:@"L"] || [x isEqualToString:@"q"] || [x isEqualToString:@"Q"] || [x isEqualToString:@"s"] || [x isEqualToString:@"S"] || [x isEqualToString:@"B"] )
#define isFloatType(x) ([x isEqualToString:@"f"] || [x isEqualToString:@"d"])
#define isStringType(x) ([x isEqualToString:@"c"] || [x isEqualToString:@"C"])

@interface LPDBModel : NSObject {
@private
    NSInteger _pk;
    BOOL _dirty;
}
- (BOOL)isDirty;

- (void)save;

- (NSArray *)query:(NSArray *)formatString, ...;

@end


@interface NSString (PropType)
- (BOOL)isIntegerType;
- (BOOL)isFloatType;
- (BOOL)isStringType;
@end
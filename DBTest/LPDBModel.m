//
//  LPDBModel.m
//  DBTest
//
//  Created by 鹏 李 on 7/21/15.
//  Copyright (c) 2015 Cocoamad. All rights reserved.
//

#import "LPDBModel.h"
#import <objc/runtime.h>
#import "LPDBManager.h"
#import "NSObject-ClassName.h"
#import "NSString-SQLiteColumnName.h"
#import "NSString-SQLitePersistence.h"

NSMutableDictionary *objectMap;
NSMutableArray *checkedTables;

@interface LPDBModel(Private)
+ (NSDictionary *)propertiesWithEncodedTypes;

+ (void)tableCheck;
+ (BOOL)tableExists;
+ (NSString *)tableName;
@end


@implementation LPDBModel

+ (NSDictionary *)propertiesWithEncodedTypes
{
    // Recurse up the classes, but stop at NSObject. Each class only reports its own properties, not those inherited from its superclass
    
    NSMutableDictionary *theProps;
    
    if ([self superclass] != [NSObject class])
        theProps = (NSMutableDictionary *)[[self superclass] propertiesWithEncodedTypes];
    else
        theProps = [NSMutableDictionary dictionary];
    
    unsigned int outCount;
    
    objc_property_t *propList = class_copyPropertyList([self class], &outCount);
    int i;
    
    // Loop through properties and add declarations for the create
    for (i=0; i < outCount; i++)
    {
        objc_property_t oneProp = propList[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(oneProp)];
        NSString *attrs = [NSString stringWithUTF8String: property_getAttributes(oneProp)];
        // Read only attributes are assumed to be derived or calculated
        // See http://developer.apple.com/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/chapter_8_section_3.html
        if ([attrs rangeOfString:@",R,"].location == NSNotFound)
        {
            NSArray *attrParts = [attrs componentsSeparatedByString:@","];
            if (attrParts != nil)
            {
                if ([attrParts count] > 0)
                {
                    NSString *propType = [[attrParts objectAtIndex:0] substringFromIndex:1];
                    [theProps setObject:propType forKey:propName];
                }
            }
        }
    }
    free(propList);
    return theProps;
}

+ (BOOL)tableExists
{
    __block BOOL exists = NO;
    [[LPDBManager shareManager].queue inDatabase:^(FMDatabase *db) {
        NSString *query = [NSString stringWithFormat: @"SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%@'", [self tableName]];
        FMResultSet *set = [db executeQuery: query];
        if ([set next]) {
            exists = [set intForColumn: @"count(*)"];
        }
        [set close];
    }];
    return exists;
}

+ (NSString *)tableName
{
    static NSMutableDictionary *tableNamesByClass = nil;
    
    if (tableNamesByClass == nil)
        tableNamesByClass = [[NSMutableDictionary alloc] init];
    
    if ([[tableNamesByClass allKeys] containsObject:[self className]])
        return [tableNamesByClass objectForKey:[self className]];
    
    NSMutableString *ret = [NSMutableString string];
    NSString *className = [self className];
    for (int i = 0; i < className.length; i++)
    {
        NSRange range = NSMakeRange(i, 1);
        NSString *oneChar = [className substringWithRange:range];
        if ([oneChar isEqualToString:[oneChar uppercaseString]] && i > 0)
            [ret appendFormat:@"_%@", [oneChar lowercaseString]];
        else
            [ret appendString:[oneChar lowercaseString]];
    }
    
    [tableNamesByClass setObject:ret forKey:[self className]];
    return ret;
}

+ (NSArray *)tableColumns
{
    NSMutableArray *columns = [NSMutableArray array];
    [[LPDBManager shareManager].queue inDatabase:^(FMDatabase *db) {
        FMResultSet *set = [db executeQuery:[NSString stringWithFormat:@"PRAGMA table_info(%@)", [self tableName]]];
        if ([set next]) {
            while ([set next]) {
                [columns addObject:[set stringForColumn: @"name"]];
            }
        }
        [set close];
    }];
    return columns;
}


+ (void)tableCheck
{
    if (checkedTables == nil)
        checkedTables = [[NSMutableArray alloc] init];

    if (![checkedTables containsObject: [self className]]) {
        [checkedTables addObject: [self className]];
    }
    
    if ([self tableExists]) {
        NSArray *columns = [self tableColumns];
        NSDictionary* props = [[self class] propertiesWithEncodedTypes];
        NSArray *allProps = [props allKeys];
 
        NSMutableArray *insertColumnsSQLs = [NSMutableArray array];
        
        for (NSString *oneProp in allProps) {
            NSString *propName = [oneProp stringAsSQLColumnName];
            if (![columns containsObject: propName]) { // if not include in table
               NSMutableString *insertColumnSQL = [NSMutableString stringWithFormat: @"alter table %@ add column ", [self tableName]];
                NSString *propType = props[oneProp];
                if (isIntegerType(propType)) {
                    [insertColumnSQL appendFormat:@"%@ INTEGER", propName];
                }
                else if (isStringType(propType)) {
                    [insertColumnSQL appendFormat:@"%@ TEXT", propName];
                }
                else if (isFloatType(propType)) {
                    [insertColumnSQL appendFormat:@"%@ REAL", propName];
                } else if ([propType hasPrefix:@"@"]) {
                    NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
                    if (isNSArrayType(className)) {
                        
                    }
                    else if (isNSDictionaryType(className)) {
                        
                    }
                    else if (isNSSetType(className)) {
                        
                    }
                    else {
                        Class propClass = objc_lookUpClass([className UTF8String]);
                        if ([propClass isSubclassOfClass:[LPDBModel class]]) {
                            [insertColumnSQL appendFormat:@"%@ TEXT", propName];
                        } else if ([propClass canBeStoredInSQLite]) {
                            [insertColumnSQL appendFormat:@"%@ %@", propName, [propClass columnTypeForObjectStorage]];
                        }
                    }
                }
                [insertColumnsSQLs addObject: insertColumnSQL];
            }
        }
        if (insertColumnsSQLs.count) {
            [[LPDBManager shareManager].queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                for (NSString *insertColumnSQl in insertColumnsSQLs) {
                    NSLog(@"%@", insertColumnSQl);
                    [db executeUpdate: insertColumnSQl];
                }
            }];
        }
        
    } else {
        NSMutableString *createSQL = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (pk INTEGER PRIMARY KEY autoincrement",[self  tableName]];
        NSDictionary* props = [[self class] propertiesWithEncodedTypes];
        NSArray *allProps = [props allKeys];
        for (NSString *oneProp in allProps) {
            
            NSString *propName = [oneProp stringAsSQLColumnName];
            NSString *propType = [props objectForKey:oneProp];
            
            if (isIntegerType(propType)) {
                [createSQL appendFormat:@", %@ INTEGER", propName];
            }
            else if (isStringType(propType)) {
                [createSQL appendFormat:@", %@ TEXT", propName];
            }
            else if (isFloatType(propType)) {
                [createSQL appendFormat:@", %@ REAL", propName];
            } else if ([propType hasPrefix:@"@"]) {
                NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
                if (isNSArrayType(className)) {
                    
                }
                else if (isNSDictionaryType(className)) {
                    
                }
                else if (isNSSetType(className)) {

                }
                else {
                    Class propClass = objc_lookUpClass([className UTF8String]);
                    if ([propClass isSubclassOfClass:[LPDBModel class]]) {
                        [createSQL appendFormat:@", %@ TEXT", propName];
                    } else if ([propClass canBeStoredInSQLite]) {
                        [createSQL appendFormat:@", %@ %@", propName, [propClass columnTypeForObjectStorage]];
                    }
                }
            }
        }
        [createSQL appendString:@")"];
        
        [[LPDBManager shareManager].queue inDatabase:^(FMDatabase *db) {
            BOOL success = [db executeUpdate: createSQL];
            assert(success);
        }];
        
        
    }
}

+ (void)initialize
{
    NSLog(@"%@", [self className]);
    
    if (![[self className] isEqualToString: @"LPDBModel"]) {
        [self tableCheck];
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        _pk = -1;
        _dirty = YES;
//        for (NSString *oneProp in [[self class] propertiesWithEncodedTypes])
//            [self addObserver: self forKeyPath: oneProp options: 0 context: nil];
    }
    return self;
}

- (void)dealloc
{
//    for (NSString *oneProp in [[self class] propertiesWithEncodedTypes])
//         [self removeObserver: self forKeyPath: oneProp];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    _dirty = YES;
}

- (BOOL)isDirty
{
    return _dirty;
}

- (void)save
{
    NSDictionary *props = [[self class] propertiesWithEncodedTypes];
    NSArray *allPropNames = [props allKeys];
    
    if (_pk == -1) { // record not ever saved
        _dirty = YES;
    } else {
        for (NSString *propName in allPropNames) {
            NSString *propType = [props objectForKey:propName];
            id theProperty = [self valueForKey:propName];
            if ([propType hasPrefix: @"@"]) { // it's object
                NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
                if (!(isCollectionType(className))) {
                    if ([[theProperty class] isSubclassOfClass:[LPDBModel class]])
                        if ([(LPDBModel *)theProperty isDirty])
                            _dirty = YES;
                } else {
                    if (isNSSetType(className) || isNSArrayType(className)) {
                        for (id oneObject in (NSArray *)theProperty) {
                            if ([oneObject isKindOfClass:[LPDBModel class]]) {
                                if ([oneObject isDirty]) {
                                    _dirty = YES;
                                    break;
                                }
                            } else if (isNSDictionaryType(oneObject)) {
                                for (id oneKey in [theProperty allKeys]) {
                                    id oneObject = [theProperty objectForKey: oneKey];
                                    if ([oneObject isKindOfClass:[LPDBModel class]])
                                        if ([(LPDBModel *)oneObject isDirty]) {
                                            _dirty = YES;
                                            break;
                                        }
                                }
                            }
                        }
                    }
                }
            }
            if (_dirty)
                break;
        }
    }
    
    if (_dirty) {
        _dirty = NO;
        NSMutableString *updateSQL = [NSMutableString stringWithFormat:@"INSERT OR REPLACE INTO %@ (", [[self class] tableName]];
        NSMutableString *bindSQL = [NSMutableString string];
        NSInteger index = 0;
        for (NSString *propName in allPropNames) {
            NSString *propType = [props objectForKey: propName];
            NSString *className = @"";
            if ([propType hasPrefix: @"@"])
                className = [propType substringWithRange: NSMakeRange(2, [propType length] - 3)];
            if (!(isCollectionType(className))) {
                if (index++ == allPropNames.count - 1) {
                    [updateSQL appendFormat: @"%@", [propName stringAsSQLColumnName]];
                    [bindSQL appendString: @"?"];
                } else {
                    [updateSQL appendFormat: @"%@, ", [propName stringAsSQLColumnName]];
                    [bindSQL appendString: @"?, "];
                }
            }
        }
        
        [updateSQL appendFormat:@") VALUES (%@)", bindSQL];
        
        NSLog(@"%@", updateSQL);
    }
}

- (NSArray *)query:(NSArray *)formatString, ...
{
    return nil;
}


@end

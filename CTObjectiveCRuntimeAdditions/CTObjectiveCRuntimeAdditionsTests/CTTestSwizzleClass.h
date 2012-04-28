//
//  CTTestSwizzleClass.h
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright 2012 ebf. All rights reserved.
//



/**
 @abstract  <#abstract comment#>
 */
@interface CTTestSwizzleClass : NSObject {
@private
    
}

- (NSString *)orginalString;
- (NSString *)__hookedOriginalString;

- (NSString *)stringTwo;
- (NSString *)__prefixedHookedStringTwo;

+ (NSString *)stringThree;
+ (NSString *)__prefixedHookedStringThree;

- (NSString *)stringByJoiningString:(NSString *)string withWith:(NSString *)suffix;
- (NSString *)__prefixedHookedStringByJoiningString:(NSString *)string withWith:(NSString *)suffix;

- (NSString *)__prefixedHookedStringFive;

+ (BOOL)passesTest;

@end

//
//  CTTestSwizzleClass.m
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright 2012 ebf. All rights reserved.
//

#import "CTTestSwizzleClass.h"



@interface CTTestSwizzleClass () {
    
}

@end



@implementation CTTestSwizzleClass

#pragma mark - Initialization

- (id)init 
{
    if (self = [super init]) {
        // Initialization code
    }
    return self;
}

#pragma mark - Instance methods

- (CGPoint)pointByAddingPoint:(CGPoint)point
{
    return CGPointMake(point.x + 1.0f, point.y + 1.0f);
}

- (NSString *)helloWorldStringFromString:(NSString *)string
{
    return [@"Hello World" stringByAppendingFormat:@" %@", string];
}

- (NSString *)orginalString
{
    return @"foo";
}

- (NSString *)__hookedOriginalString
{
    NSString *original = [self __hookedOriginalString];
    return [original stringByAppendingString:@"bar"];
}

- (NSString *)stringTwo
{
    return @"foo";
}

- (NSString *)__prefixedHookedStringTwo
{
    NSString *original = [self __prefixedHookedStringTwo];
    return [original stringByAppendingString:@"bar"];
}

+ (NSString *)stringThree
{
    return @"foo";
}

+ (NSString *)__prefixedHookedStringThree
{
    NSString *original = [self __prefixedHookedStringThree];
    return [original stringByAppendingString:@"bar"];
}

- (NSString *)stringByJoiningString:(NSString *)string withWith:(NSString *)suffix
{
    return [string stringByAppendingString:suffix];
}

- (NSString *)__prefixedHookedStringByJoiningString:(NSString *)string withWith:(NSString *)suffix
{
    NSString *original = [self __prefixedHookedStringByJoiningString:string withWith:suffix];
    return [original stringByAppendingString:@"bar"];
}

- (NSString *)__prefixedHookedStringFive
{
    return @"foo";
}

+ (BOOL)passesTest
{
    return NO;
}

#pragma mark - Memory management

- (void)dealloc
{
    
}

#pragma mark - Private category implementation ()

@end

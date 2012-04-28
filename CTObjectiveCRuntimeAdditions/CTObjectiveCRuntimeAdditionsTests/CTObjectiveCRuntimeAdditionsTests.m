//
//  CTObjectiveCRuntimeAdditionsTests.m
//  CTObjectiveCRuntimeAdditionsTests
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright (c) 2012 Home. All rights reserved.
//

#import "CTObjectiveCRuntimeAdditionsTests.h"
#import "CTObjectiveCRuntimeAdditions.h"
#import "CTTestSwizzleClass.h"
#import "CTTestSwizzleSubclass.h"

@implementation CTObjectiveCRuntimeAdditionsTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testMethodSwizzling
{
    CTTestSwizzleClass *testObject = [[CTTestSwizzleClass alloc] init];
    NSString *originalString = testObject.orginalString;
    
    class_swizzleSelector(CTTestSwizzleClass.class, @selector(orginalString), @selector(__hookedOriginalString));
    
    NSString *hookedString = testObject.orginalString;
    
    STAssertFalse([originalString isEqualToString:hookedString], @"originalDescription cannot be equal to hookedDescription.");
    STAssertEqualObjects(originalString, @"foo", @"originalString wrong.");
    STAssertTrue([hookedString hasSuffix:@"foobar"], @"hookedDescription should have suffix 'bar'.");
}

- (void)testAutomaticMethodSwizzlingWithMethodPrefix
{
    CTTestSwizzleClass *testObject = [[CTTestSwizzleClass alloc] init];
    
    NSString *originalString = testObject.stringTwo;
    NSString *originalStringThree = [CTTestSwizzleClass stringThree];
    NSString *originalJoinedString = [testObject stringByJoiningString:@"my" withWith:@"string"];
    
    NSString *originalStringFive = testObject.__prefixedHookedStringFive;
    
    class_swizzlesMethodsWithPrefix(CTTestSwizzleClass.class, @"__prefixedHooked");
    
    NSString *hookedString = testObject.stringTwo;
    NSString *hookedStringThree = [CTTestSwizzleClass stringThree];
    NSString *hookedJoinedString = [testObject stringByJoiningString:@"my" withWith:@"string"];
    
    STAssertFalse([originalString isEqualToString:hookedString], @"originalString cannot be equal to hookedString.");
    STAssertEqualObjects(originalString, @"foo", @"originalString wrong.");
    STAssertTrue([hookedString hasSuffix:@"foobar"], @"hookedString should have suffix 'bar'.");
    
    STAssertFalse([originalStringThree isEqualToString:hookedStringThree], @"originalStringThree cannot be equal to hookedStringThree.");
    STAssertEqualObjects(originalStringThree, @"foo", @"originalStringThree wrong.");
    STAssertTrue([hookedStringThree hasSuffix:@"foobar"], @"hookedStringThree should have suffix 'bar'.");
    
    STAssertFalse([originalJoinedString isEqualToString:hookedJoinedString], @"originalJoinedString cannot be equal to hookedJoinedString.");
    STAssertEqualObjects(originalJoinedString, @"mystring", @"originalJoinedString wrong.");
    STAssertTrue([hookedJoinedString hasSuffix:@"mystringbar"], @"hookedJoinedString should have suffix 'bar'.");
    
    STAssertEqualObjects(originalStringFive, @"foo", @"something went wrong with swizzling a method that doesn't have an original method without the prefix.");
}

- (void)testDynamicSubclassFinding
{
    Class subclass = class_subclassPassingTest(CTTestSwizzleClass.class, ^BOOL(__unsafe_unretained Class subclass) {
        return [subclass passesTest];
    });
    
    STAssertEqualObjects(subclass, CTTestSwizzleSubclass.class, @"subclass that passes test should be CTTestSwizzleSubclass");
}

@end

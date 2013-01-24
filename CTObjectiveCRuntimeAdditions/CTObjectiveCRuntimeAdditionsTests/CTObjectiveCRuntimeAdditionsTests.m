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
#import "CTBlockDescription.h"

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

- (void)testBlockDescription
{
    BOOL(^testBlock)(BOOL animated, id object) = ^BOOL(BOOL animated, id object) {
        return YES;
    };
    
    CTBlockDescription *blockDescription = [[CTBlockDescription alloc] initWithBlock:testBlock];
    NSMethodSignature *methodSignature = blockDescription.blockSignature;
    
    STAssertEquals(strcmp(methodSignature.methodReturnType, @encode(BOOL)), 0, @"return type wrong");
    
    const char *expectedArguments[] = {@encode(typeof(testBlock)), @encode(BOOL), @encode(id)};
    for (int i = 0; i < blockDescription.blockSignature.numberOfArguments; i++) {
        STAssertEquals(strcmp([blockDescription.blockSignature getArgumentTypeAtIndex:i], expectedArguments[i]), 0, @"Argument %d wrong", i);
    }
}

- (void)testBlockSwizzling
{
    Class class = [CTTestSwizzleClass class];
    CTTestSwizzleClass *testObject = [[CTTestSwizzleClass alloc] init];
    NSString *originalString = [testObject helloWorldStringFromString:@"Oli"];
    
    STAssertEqualObjects(originalString, @"Hello World Oli", @"Original helloWorldString wrong");
    
    __block IMP implementation1 = class_replaceMethodWithBlock(class, @selector(helloWorldStringFromString:), ^NSString *(CTTestSwizzleClass *blockSelf, NSString *string) {
        STAssertEqualObjects(blockSelf, testObject, @"blockSelf is wrong");
        return [implementation1(blockSelf, @selector(helloWorldStringFromString:), string) stringByAppendingFormat:@" Hooked"];
    });
    
    STAssertEqualObjects([testObject helloWorldStringFromString:@"Oli"], @"Hello World Oli Hooked", @"did not swizzle with block");
    
    __block IMP implementation2 = class_replaceMethodWithBlock(class, @selector(helloWorldStringFromString:), ^NSString *(CTTestSwizzleClass *blockSelf, NSString *string) {
        STAssertEqualObjects(blockSelf, testObject, @"blockSelf is wrong");
        return [implementation2(blockSelf, @selector(helloWorldStringFromString:), string) stringByAppendingFormat:@" Hooked2"];
    });
    
    STAssertEqualObjects([testObject helloWorldStringFromString:@"Oli"], @"Hello World Oli Hooked Hooked2", @"did not swizzle with block");
    
    
    // test structs
    STAssertEquals(CGPointMake(2.0f, 2.0f), [testObject pointByAddingPoint:CGPointMake(1.0f, 1.0f)], @"initial point wrong");
    
    typedef CGPoint(*pointImplementation)(id self, SEL _cmd, CGPoint point);
    
    __block pointImplementation implementation3 = (pointImplementation)class_replaceMethodWithBlock(class, @selector(pointByAddingPoint:), ^CGPoint(CTTestSwizzleClass *blockSelf, CGPoint point) {
        STAssertEqualObjects(blockSelf, testObject, @"blockSelf is wrong");
        
        CGPoint originalPoint = implementation3(blockSelf, @selector(pointByAddingPoint:), point);
        return CGPointMake(originalPoint.x + 1.0f, originalPoint.y + 1.0f);
    });
    
    STAssertEquals(CGPointMake(3.0f, 3.0f), [testObject pointByAddingPoint:CGPointMake(1.0f, 1.0f)], @"initial point wrong");
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

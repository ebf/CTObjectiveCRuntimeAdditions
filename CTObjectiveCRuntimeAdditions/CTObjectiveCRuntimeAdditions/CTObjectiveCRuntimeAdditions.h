//
//  CTObjectiveCRuntimeAdditions.h
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright (c) 2012 ebf. All rights reserved.
//

typedef void(^CTMethodEnumertor)(Class class, Method method);
typedef BOOL(^CTClassTest)(Class subclass);

/**
 @abstract Swizzles originalSelector with newSelector.
 */
void class_swizzleSelector(Class class, SEL originalSelector, SEL newSelector);

/**
 @abstract Swizzles all methods of a class with a given prefix with the corresponding SEL without the prefix. @selector(__hookedLoadView) will be swizzled with @selector(loadView). This method also swizzles class methods with a given prefix.
 */
void class_swizzlesMethodsWithPrefix(Class class, NSString *prefix);

/**
 @abstract Enumerate class methods.
 */
void class_enumerateMethodList(Class class, CTMethodEnumertor enumerator);

/**
 @return A subclass of class which passes test.
 */
Class class_subclassPassingTest(Class class, CTClassTest test);

/**
 @abstract Swizzles originalSelector with block and places original implementation in unusedSelector.
 @warning if originalSelector's argument list is (id self, SEL _cmd, ...), then block's argument list must be (id self, IMP originalImplemenation, ...)
 */
void class_swizzleSelectorWithBlock(Class class, SEL originalSelector, SEL unusedSelector, id block);

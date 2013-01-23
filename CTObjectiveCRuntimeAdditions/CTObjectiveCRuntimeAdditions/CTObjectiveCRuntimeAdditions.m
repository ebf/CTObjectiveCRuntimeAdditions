//
//  CTObjectiveCRuntimeAdditions.m
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright (c) 2012 ebf. All rights reserved.
//

#import "CTObjectiveCRuntimeAdditions.h"
#import "CTBlockDescription.h"
#import "CTSwizzleBlockImplementation.h"

static NSMutableArray *CTBlockImplementations;

__attribute((constructor))void CTObjectiveCRuntimeAdditionsInitialization(void)
{
    @autoreleasepool {
        CTBlockImplementations = [NSMutableArray array];
    }
}

void class_swizzleSelector(Class class, SEL originalSelector, SEL newSelector)
{
    Method origMethod = class_getInstanceMethod(class, originalSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    if(class_addMethod(class, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(class, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

void class_swizzlesMethodsWithPrefix(Class class, NSString *prefix)
{
    CTMethodEnumertor enumeratorBlock = ^(Class class, Method method) {
        SEL methodSelector = method_getName(method);
        NSString *selectorString = NSStringFromSelector(methodSelector);
        
        if ([selectorString hasPrefix:prefix]) {
            NSMutableString *originalSelectorString = [selectorString stringByReplacingOccurrencesOfString:prefix withString:@"" options:NSLiteralSearch range:NSMakeRange(0, prefix.length)].mutableCopy;
            
            if (originalSelectorString.length > 0) {
                NSString *uppercaseFirstCharacter = [originalSelectorString substringToIndex:1];
                NSString *lowercaseFirstCharacter = uppercaseFirstCharacter.lowercaseString;
                
                [originalSelectorString replaceCharactersInRange:NSMakeRange(0, 1) withString:lowercaseFirstCharacter];
                
                SEL originalSelector = NSSelectorFromString(originalSelectorString);
                
                class_swizzleSelector(class, originalSelector, methodSelector);
            }
        }
    };
    
    // swizzle instance methods
    class_enumerateMethodList(class, enumeratorBlock);
    
    // swizzle class methods
    Class metaClass = objc_getMetaClass(class_getName(class));
    class_enumerateMethodList(metaClass, enumeratorBlock);
}

void class_enumerateMethodList(Class class, CTMethodEnumertor enumerator)
{
    if (!enumerator) return;
    
    static dispatch_queue_t queue = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("de.ebf.objc_runtime_additions.method_enumeration_queue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(class, &methodCount);
    
    dispatch_apply(methodCount, queue, ^(size_t index) {
        Method method = methods[index];
        enumerator(class, method);
    });
    
    free(methods);
}

Class class_subclassPassingTest(Class class, CTClassTest test)
{
    if (!test) return nil;
    
    static dispatch_queue_t queue = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("de.ebf.objc_runtime_additions.class_queue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    unsigned int numberOfClasses = 0;
    Class *classList = objc_copyClassList(&numberOfClasses);
    
    __block Class testPassingClass = nil;
    
    dispatch_apply(numberOfClasses, queue, ^(size_t classIndex) {
        if (testPassingClass != nil) {
            return;
        }
        
        Class thisClass = classList[classIndex];
        Class superClass = thisClass;
        
        while ((superClass = class_getSuperclass(superClass))) {
            if (superClass == class || thisClass == class) {
                if (test(thisClass)) {
                    testPassingClass = thisClass;
                }
            }
        }
    });
    
    // cleanup
    free(classList);
    
    return testPassingClass;
}

void class_swizzleSelectorWithBlock(Class class, SEL originalSelector, SEL unusedSelector, id block)
{
    NSCAssert(block != nil, @"block cannot be nil");
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(originalMethod)];
    
    CTBlockDescription *blockDescription = [[CTBlockDescription alloc] initWithBlock:block];
    NSCAssert([blockDescription isCompatibleForBlockSwizzlingWithMethodSignature:methodSignature], @"block is not compatible for swizzling selector %@ of class %@", NSStringFromSelector(originalSelector), NSStringFromClass(class));
    
    CTSwizzleBlockImplementation *blockImplementation = [[CTSwizzleBlockImplementation alloc] initWithBlock:block
                                                                                            methodSignature:methodSignature
                                                                                           swizzledSelector:unusedSelector
                                                                                              originalClass:class];
    [CTBlockImplementations addObject:blockImplementation];
    
    BOOL success = class_addMethod(class, unusedSelector, blockImplementation.implementation, method_getTypeEncoding(originalMethod));
    NSCAssert(success, @"An implementation for selector %@ of class %@ already exists", NSStringFromSelector(unusedSelector), NSStringFromClass(class));
    
    class_swizzleSelector(class, originalSelector, unusedSelector);
}

void class_implementPropertyInUserDefaults(Class class, NSString *propertyName, BOOL automaticSynchronizeUserDefaults)
{
    NSString *userDefaultsKey = [NSString stringWithFormat:@"%@__%@", NSStringFromClass(class), propertyName];
    
    SEL getter = NSSelectorFromString(propertyName);
    NSString *firstLetter = [propertyName substringToIndex:1];
    NSString *setterName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"set%@", firstLetter.uppercaseString]];
    setterName = [setterName stringByAppendingString:@":"];
    SEL setter = NSSelectorFromString(setterName);
    
    IMP getterImplementation = imp_implementationWithBlock(^id(id self) {
        // 1) try to read from cache
        return [[NSUserDefaults standardUserDefaults] objectForKey:userDefaultsKey];
    });
    
    IMP setterImplementation = imp_implementationWithBlock(^(id self, id object) {
        if (!object) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:userDefaultsKey];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:object forKey:userDefaultsKey];
            
            if (automaticSynchronizeUserDefaults) {
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    });
    
    class_addMethod(class, getter, getterImplementation, "@@:");
    class_addMethod(class, setter, setterImplementation, "v@:@");
}

void class_implementProperty(Class class, NSString *propertyName, objc_AssociationPolicy associationPolicy)
{
    SEL getter = NSSelectorFromString(propertyName);
    NSString *firstLetter = [propertyName substringToIndex:1];
    NSString *setterName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"set%@", firstLetter.uppercaseString]];
    setterName = [setterName stringByAppendingString:@":"];
    SEL setter = NSSelectorFromString(setterName);
    
    IMP getterImplementation = imp_implementationWithBlock(^id(id self) {
        // 1) try to read from cache
        return objc_getAssociatedObject(self, getter);
    });
    
    IMP setterImplementation = imp_implementationWithBlock(^(id self, id object) {
        objc_setAssociatedObject(self, getter, object, associationPolicy);
    });
    
    class_addMethod(class, getter, getterImplementation, "@@:");
    class_addMethod(class, setter, setterImplementation, "v@:@");
}

//
//  CTObjectiveCRuntimeAdditions.m
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright (c) 2012 ebf. All rights reserved.
//

#import "CTObjectiveCRuntimeAdditions.h"
#import "CTBlockDescription.h"

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

IMP class_replaceMethodWithBlock(Class class, SEL originalSelector, id block)
{
    IMP newImplementation = imp_implementationWithBlock(block);
    
    Method method = class_getInstanceMethod(class, originalSelector);
    return class_replaceMethod(class, originalSelector, newImplementation, method_getTypeEncoding(method));
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

__attribute__((overloadable))
void class_implementProperty(Class class, NSString *propertyName)
{
    class_implementProperty(class, propertyName, OBJC_ASSOCIATION_RETAIN_NONATOMIC, @encode(id));
}

__attribute__((overloadable))
void class_implementProperty(Class class, NSString *propertyName, objc_AssociationPolicy associationPolicy)
{
    class_implementProperty(class, propertyName, associationPolicy, @encode(id));
}

__attribute__((overloadable))
void class_implementProperty(Class class, NSString *propertyName, char *const encoding)
{
    class_implementProperty(class, propertyName, OBJC_ASSOCIATION_RETAIN_NONATOMIC, encoding);
}

__attribute__((overloadable))
void class_implementProperty(Class class, NSString *propertyName, objc_AssociationPolicy associationPolicy, char *const encoding)
{
    NSCAssert(encoding != NULL, @"encoding cannot be null");
    
    SEL getter = NSSelectorFromString(propertyName);
    NSString *firstLetter = [propertyName substringToIndex:1];
    NSString *setterName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"set%@", firstLetter.uppercaseString]];
    setterName = [setterName stringByAppendingString:@":"];
    SEL setter = NSSelectorFromString(setterName);
        
    if (encoding[0] == @encode(id)[0]) {
        IMP getterImplementation = imp_implementationWithBlock(^id(id self) {
            return objc_getAssociatedObject(self, getter);
        });
        
        IMP setterImplementation = imp_implementationWithBlock(^(id self, id object) {
            objc_setAssociatedObject(self, getter, object, associationPolicy);
        });
        
        class_addMethod(class, getter, getterImplementation, "@@:");
        class_addMethod(class, setter, setterImplementation, "v@:@");
        
        return;
    }
    
#define CASE(type, selectorpart) if (encoding[0] == @encode(type)[0]) {\
    IMP getterImplementation = imp_implementationWithBlock(^type(id self) {\
        return [objc_getAssociatedObject(self, getter) selectorpart##Value];\
    });\
    \
    IMP setterImplementation = imp_implementationWithBlock(^(id self, type object) {\
        objc_setAssociatedObject(self, getter, @(object), associationPolicy);\
    });\
    \
    class_addMethod(class, getter, getterImplementation, "@@:");\
    class_addMethod(class, setter, setterImplementation, "v@:@");\
    \
    return;\
}

    if (encoding[0] == @encode(BOOL)[0]) {
        IMP getterImplementation = imp_implementationWithBlock(^BOOL(id self) {
            return [objc_getAssociatedObject(self, getter) boolValue];
        });
        
        IMP setterImplementation = imp_implementationWithBlock(^(id self, BOOL object) {
            objc_setAssociatedObject(self, getter, @(object), associationPolicy);
        });
        
        class_addMethod(class, getter, getterImplementation, "@@:");
        class_addMethod(class, setter, setterImplementation, "v@:@");
        
        return;
    }
    
    CASE(char, char);
    CASE(unsigned char, unsignedChar);
    CASE(short, short);
    CASE(unsigned short, unsignedShort);
    CASE(int, int);
    CASE(unsigned int, unsignedInt);
    CASE(long, long);
    CASE(unsigned long, unsignedLong);
    CASE(long long, longLong);
    CASE(unsigned long long, unsignedLongLong);
    CASE(float, float);
    CASE(double, double);
    CASE(BOOL, bool);
    
    NSCAssert(NO, @"encoding %s in not supported for %s", encoding, __PRETTY_FUNCTION__);
}

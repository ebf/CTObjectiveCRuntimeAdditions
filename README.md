CTObjectiveCRuntimeAdditions
============================

Some Objective-C runtime additions.

Swizzeling methods with blocks
============================
If you wanted to swizzle a method before, you would have to declare a category on a class (usually resulting in two extra files).

CTObjectiveCRuntimeAdditions introduces a new method `void class_swizzleSelectorWithBlock(Class class, SEL originalSelector, SEL unusedSelector, id block);` which takes the class, the selector you want to swizzle, an unused selector in which the previous implementation will be stored and a block that will be called instead of the original implementation.

The block must come with a defined argument list as follows:

* return type of previous implemention must match the return type of the block.
* first argument must be an object which will be self
* second argument must be an implementation pointer, which will be passed to the block to be able to call the previous implementation
* further arguments must be the as of the original implementation after its `SEL _cmd` argument

Example:

If we take the following class as an example
``` objc
@interface CTTestSwizzleClass : NSObject {

- (NSString *)helloWorldStringFromString:(NSString *)string;

@end

@implementation CTTestSwizzleClass

- (NSString *)helloWorldStringFromString:(NSString *)string
{
    return [@"Hello World" stringByAppendingFormat:@" %@", string];
}

@end
```

one could swizzle the selector `@selector(helloWorldStringFromString:)` as follows:

``` objc
class_swizzleSelectorWithBlock([CTTestSwizzleClass class], @selector(helloWorldStringFromString:), @selector(__hookedHelloWorldStringFromString:), ^NSString *(CTTestSwizzleClass *blockSelf, IMP originalImplementation, NSString *string) {
    return [originalImplementation(blockSelf, @selector(__hookedHelloWorldStringFromString:), string) stringByAppendingFormat:@" Hooked"];
});
```

Now the following code

``` objc
CTTestSwizzleClass *testObject = [[CTTestSwizzleClass alloc] init];
NSLog(@"%@", [testObject helloWorldStringFromString:@"Oli"]);
```

would produce the output `Hello World Oli Hooked` instead of just `Hello World Oli`.


Getting runtime information about blocks
============================
[CTBlockDescription](https://github.com/ebf/CTObjectiveCRuntimeAdditions/blob/master/CTObjectiveCRuntimeAdditions/CTObjectiveCRuntimeAdditions/CTBlockDescription.h) lets you inspect blocks including arguments and compile time features at runtime.

One could use CTBlockDescription for the following test block:

``` objc
// a test block.
BOOL(^testBlock)(BOOL animated, id object) = ^BOOL(BOOL animated, id object) {
    return YES;
};

// allocating a block description
CTBlockDescription *blockDescription = [[CTBlockDescription alloc] initWithBlock:testBlock];

// getting a method signature for this block
NSMethodSignature *methodSignature = blockDescription.blockSignature;
/**
<NSMethodSignature: 0x253f080>
    number of arguments = 3
    frame size = 12
    is special struct return? NO
    return value: -------- -------- -------- --------
        type encoding (c) 'c'
        flags {isSigned}
        modifiers {}
        frame {offset = 0, offset adjust = 0, size = 4, size adjust = -3}
        memory {offset = 0, size = 1}
    argument 0: -------- -------- -------- --------
        type encoding (@) '@?'
        flags {isObject, isBlock}
        modifiers {}
        frame {offset = 0, offset adjust = 0, size = 4, size adjust = 0}
        memory {offset = 0, size = 4}
    argument 1: -------- -------- -------- --------
        type encoding (c) 'c'
        flags {isSigned}
        modifiers {}
        frame {offset = 4, offset adjust = 0, size = 4, size adjust = -3}
        memory {offset = 0, size = 1}
    argument 2: -------- -------- -------- --------
        type encoding (@) '@'
        flags {isObject}
        modifiers {}
        frame {offset = 8, offset adjust = 0, size = 4, size adjust = 0}
        memory {offset = 0, size = 4}
*/
```



License
============================
MIT

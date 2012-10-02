CTObjectiveCRuntimeAdditions
============================

Some Objective-C runtime additions.

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

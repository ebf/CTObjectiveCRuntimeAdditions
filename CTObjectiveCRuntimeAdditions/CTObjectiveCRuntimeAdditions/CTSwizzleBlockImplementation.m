//
//  CTSwizzleBlockImplementation.m
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 02.09.12.
//  Copyright 2012 ebf. All rights reserved.
//

#import "CTSwizzleBlockImplementation.h"
#import "CTBlockDescription.h"
#import <ffi.h>
#import <objc/message.h>

@interface CTSwizzleBlockImplementation () {
@package
    NSMutableArray *_allocations;
    void *_methodCIF;
    void *_blockCIF;
    void *_closure;
    id _block;
    
    SEL _swizzledSelector;
    Class _swizzledClass;
    
    int _numberOfMethodArguments;
}

- (void *)_allocatePersistentMemoryWithSize:(size_t)size;
- (size_t)_getNumberOfArgumentsInStructWithEncoding:(const char *)structEncoding;
- (const char *)_skipStructNameOfStructWithEncoding:(const char *)structEncoding;
- (ffi_type *)_ffiTypeForObjcTypeWithEncoding:(const char *)typeEncoding;

@end

static void CTSwizzleBlockImplementationTrampoline(ffi_cif *cif, void *ret, void **args, void *userdata) {
    CTSwizzleBlockImplementation *self = (__bridge CTSwizzleBlockImplementation *)userdata;
    struct CTBlockLiteral *block = (__bridge struct CTBlockLiteral *)self->_block;
    
    void *blockArguments[self->_numberOfMethodArguments + 1];
    
    blockArguments[0] = &block;
    
    for (int i = 0; i < self->_numberOfMethodArguments; i++) {
        if (i == 1) {
            // this is the SEL _cmd
            Method originalMethod = class_getInstanceMethod(self->_swizzledClass, self->_swizzledSelector);
            IMP originalImplementation = method_getImplementation(originalMethod);
            blockArguments[i + 1] = &originalImplementation;
        } else {
            blockArguments[i + 1] = args[i];
        }
    }
    
    void (*blockInvoke)(void) = (void (*)(void))block->invoke;
    ffi_call(self->_blockCIF, blockInvoke, ret, blockArguments);
}


/**
 workflow: objc_msgSend jumps to _implementation. _implementation sorts function arguments and calls CTSwizzleBlockImplementationTrampoline. CTSwizzleBlockImplementationTrampoline updates function arguments to match required arguments for block and calls invoke of the block.
 */
@implementation CTSwizzleBlockImplementation

#pragma mark - Initialization

- (id)initWithBlock:(id)block methodSignature:(NSMethodSignature *)methodSignature swizzledSelector:(SEL)swizzledSelector originalClass:(Class)originalClass
{
    if (self = [super init]) {
        _allocations = [NSMutableArray array];
        _block = block;
        _swizzledSelector = swizzledSelector;
        _swizzledClass = originalClass;
        
		_closure = ffi_closure_alloc(sizeof(ffi_closure), &_implementation);
        _numberOfMethodArguments = (unsigned int)methodSignature.numberOfArguments;
        unsigned int numberOfBlockArguments = _numberOfMethodArguments + 1;
        
        ffi_cif methodCif, blockCif;
        
        ffi_type **methodArguments = [self _allocatePersistentMemoryWithSize:_numberOfMethodArguments * sizeof(ffi_type *)];
        ffi_type **blockArguments = [self _allocatePersistentMemoryWithSize:numberOfBlockArguments * sizeof(ffi_type *)];
        ffi_type *returnType = [self _ffiTypeForObjcTypeWithEncoding:methodSignature.methodReturnType];
        
        methodArguments[0] = methodArguments[1] = &ffi_type_pointer;
        blockArguments[0] = blockArguments[1] = blockArguments[2] = &ffi_type_pointer;
        
        for (unsigned int i = 2; i < _numberOfMethodArguments; i++) {
            methodArguments[i] = [self _ffiTypeForObjcTypeWithEncoding:[methodSignature getArgumentTypeAtIndex:i]];
            blockArguments[i + 1] = methodArguments[i];
        }
        
        ffi_status methodStatus = ffi_prep_cif(&methodCif, FFI_DEFAULT_ABI, _numberOfMethodArguments, returnType, methodArguments);
        ffi_status blockStatus = ffi_prep_cif(&blockCif, FFI_DEFAULT_ABI, numberOfBlockArguments, returnType, blockArguments);
        
        NSAssert(methodStatus == FFI_OK, @"Unable to create function interface for method. %@ %@", [self class], self.block);
        NSAssert(blockStatus == FFI_OK, @"Unable to create function interface for block. %@ %@", [self class], self.block);
        
        _methodCIF = malloc(sizeof(ffi_cif));
        *(ffi_cif *)_methodCIF = methodCif;
        
        _blockCIF =  malloc(sizeof(ffi_cif));
        *(ffi_cif *)_blockCIF = blockCif;
        
        ffi_status status = ffi_prep_closure_loc(_closure, _methodCIF, CTSwizzleBlockImplementationTrampoline, (__bridge void *)self, _implementation);
        
        NSAssert(status == FFI_OK, @"Unable to create function closure for block. %@ %@", [self class], self.block);
    }
    return self;
}

#pragma mark - Memory management

- (void)dealloc
{
    if(_closure) {
        ffi_closure_free(_closure);
    }
    if (_methodCIF) {
        free(_methodCIF);
    }
    if (_blockCIF) {
        free(_blockCIF);
    }
}

#pragma mark - Private category implementation ()

- (void *)_allocatePersistentMemoryWithSize:(size_t)size
{
    NSMutableData *data = [NSMutableData dataWithLength:size];
    [_allocations addObject:data];
    return data.mutableBytes;
}

- (size_t)_getNumberOfArgumentsInStructWithEncoding:(const char *)structEncoding
{
    if (*structEncoding != _C_STRUCT_B) {
        return -1;
    }
    
    while (*structEncoding != _C_STRUCT_E && *structEncoding++ != '='); // skip "<name>="
    
    size_t numberOfArguments = 0;
    while (*structEncoding != _C_STRUCT_E) {
        structEncoding = NSGetSizeAndAlignment(structEncoding, NULL, NULL);
        numberOfArguments++;
    }
    
    return numberOfArguments;
}

- (const char *)_skipStructNameOfStructWithEncoding:(const char *)structEncoding
{
    if (*structEncoding == _C_STRUCT_B) {
        structEncoding++;
    }
	
    if (*structEncoding == _C_UNDEF) {
        structEncoding++;
    } else if (isalpha(*structEncoding) || *structEncoding == '_') {
        while (isalnum(*structEncoding) || *structEncoding == '_') {
            structEncoding++;
        }
    } else {
        return structEncoding;
    }
    
    if (*structEncoding == '=') {
        structEncoding++;
    }
    
    return structEncoding;
}

- (ffi_type *)_ffiTypeForObjcTypeWithEncoding:(const char *)typeEncoding
{
    switch (*typeEncoding) {
        case _C_ID:
        case _C_CLASS:
        case _C_SEL:
        case _C_ATOM:
        case _C_CHARPTR:
        case _C_PTR:
            return &ffi_type_pointer; break;
		case _C_BOOL:
		case _C_UCHR:
            return &ffi_type_uchar; break;
        case _C_CHR: return &ffi_type_schar; break;
		case _C_SHT: return &ffi_type_sshort; break;
		case _C_USHT: return &ffi_type_ushort; break;
		case _C_INT: return &ffi_type_sint; break;
		case _C_UINT: return &ffi_type_uint; break;
		case _C_LNG: return &ffi_type_slong; break;
		case _C_ULNG: return &ffi_type_ulong; break;
		case _C_LNG_LNG: return &ffi_type_sint64; break;
		case _C_ULNG_LNG: return &ffi_type_uint64; break;
		case _C_FLT: return &ffi_type_float; break;
		case _C_DBL: return &ffi_type_double; break;
		case _C_VOID: return &ffi_type_void; break;
        case _C_BFLD:
        case _C_ARY_B: {
            NSUInteger size, align;
            
            NSGetSizeAndAlignment(typeEncoding, &size, &align);
            
            if (size > 0) {
                if (size == 1)
                    return &ffi_type_uchar;
                else if (size == 2)
                    return &ffi_type_ushort;
                else if (size <= 4)
                    return &ffi_type_uint;
                else {
                    ffi_type *type = [self _allocatePersistentMemoryWithSize:sizeof(ffi_type)];
                    type->size = size;
                    type->alignment = align;
                    type->type = FFI_TYPE_STRUCT;
                    type->elements = [self _allocatePersistentMemoryWithSize:(size + 1) * sizeof(ffi_type *)];
                    for (NSUInteger i = 0; i < size; i++) {
                        type->elements[i] = &ffi_type_uchar;
                    }
                    type->elements[size] = NULL;
                    return type;
                }
                break;
            }
        } case _C_STRUCT_B: {
            ffi_type *type = [self _allocatePersistentMemoryWithSize:sizeof(ffi_type)];
            type->size = 0;
            type->alignment = 0;
            type->type = FFI_TYPE_STRUCT;
            type->elements = [self _allocatePersistentMemoryWithSize:([self _getNumberOfArgumentsInStructWithEncoding:typeEncoding] + 1) * sizeof(ffi_type *)];
            
            size_t index = 0;
            typeEncoding = [self _skipStructNameOfStructWithEncoding:typeEncoding];
            while (*typeEncoding != _C_STRUCT_E) {
                type->elements[index] = [self _ffiTypeForObjcTypeWithEncoding:typeEncoding];
                typeEncoding = NSGetSizeAndAlignment(typeEncoding, NULL, NULL);
                index++;
            }
            
            return type;
            break;
        }
        default: {
			NSAssert(NO, @"Unknown typeEncoding %s", typeEncoding);
            return &ffi_type_void;
            break;
        }
    }
}

@end

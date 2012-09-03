//
//  CTSwizzleBlockImplementation.h
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 02.09.12.
//  Copyright 2012 ebf. All rights reserved.
//



/**
 @abstract  <#abstract comment#>
 */
@interface CTSwizzleBlockImplementation : NSObject

- (id)initWithBlock:(id)block
    methodSignature:(NSMethodSignature *)methodSignature
   swizzledSelector:(SEL)swizzledSelector
      originalClass:(Class)originalClass;

@property (nonatomic, readonly) id block;
@property (nonatomic, readonly) void *implementation;

@end

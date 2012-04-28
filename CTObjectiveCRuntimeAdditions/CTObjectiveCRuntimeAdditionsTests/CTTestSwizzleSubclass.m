//
//  CTTestSwizzleSubclass.m
//  CTObjectiveCRuntimeAdditions
//
//  Created by Oliver Letterer on 28.04.12.
//  Copyright 2012 ebf. All rights reserved.
//

#import "CTTestSwizzleSubclass.h"



@interface CTTestSwizzleSubclass () {
    
}

@end



@implementation CTTestSwizzleSubclass

#pragma mark - Initialization

- (id)init 
{
    if (self = [super init]) {
        // Initialization code
    }
    return self;
}

#pragma mark - Instance methods

+ (BOOL)passesTest
{
    return YES;
}

#pragma mark - Memory management

- (void)dealloc
{
    
}

#pragma mark - Private category implementation ()

@end

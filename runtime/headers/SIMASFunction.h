//
//  SIMASFunction.h
//  objectivismas
//
//  Created by Xander Gomez on 9/6/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  With my feet upon the ground I lose myself
//  Between the sounds and open wide to suck it in
//  I feel it move across my skin
//  I'm reaching up and reaching out
//  I'm reaching for the random or whatever will bewilder me
//  Whatever will bewilder me
//  And following our will and wind we may just go where no one's been
//  We'll ride the spiral to the end and may just go where no one's been

#import <Foundation/Foundation.h>
#import "SIMASRuntime.h"
#import "SIMASBlock.h"

@interface SIMASFunction : SIMASBlock {
@public
    int argumentCount;
    NSString *name;
    NSMutableArray *arguments;
    int returnTo;
}

+ (void)returnFunction:(NSArray*)args;
+ (void)jump:(NSArray*)args;
- (void)ret:(NSArray*)args;
@end

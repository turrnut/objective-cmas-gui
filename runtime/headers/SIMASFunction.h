//
//  SIMASFunction.h
//  objectivismas
//
//  Created by Xander Gomez on 9/6/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  i loved you
//  yesterday
//  before you killed
//  my family
//
//  serj tankian - empty walls
//  objc killed my family

#import <Foundation/Foundation.h>
#import "SIMASRuntime.h"

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

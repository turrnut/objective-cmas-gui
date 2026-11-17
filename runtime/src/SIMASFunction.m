//
//  SIMASFunction.m
//  objectivismas
//
//  Created by Xander Gomez on 9/6/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  why don't you ask the kids at tiananmen square?
//  was fashion the reason why they were there?
//  THEY DISGUISE IT, HYPNOTISE IT
//  TELEVISION, MADE YOU BUY IT
//  i'm just sitting in my car and
//  waiting for my--
//  she's scared that i will take her away from there
//  dreams and her country left with no one there
//  MEZMERIZE THE SIMPLE MINDED
//  PROPOGANDA LEAVES US BLINDED
//  i'm just sitting in my car and
//  waiting for my damn chipotle burrito or something idk i'm tired as fuck man gimme a break
//
//  system of a down - hypnotize

#import "SIMASFunction.h"
#import "SIMASRuntime.h"

@implementation SIMASFunction
- (id)init {
    if ((self = [super init])) self->arguments = [NSMutableArray new];
    return self;
}

- (void)reg:(NSArray*)args {
    SIMASProgram *program = [SIMASRuntime currentProgram];
    NSString *name = [args objectAtIndex:0];
    if ([name characterAtIndex:0] == '$') { [SIMASRuntime throwException:@"IllegalName" withReason:@"Names starting with '$' are reserved by the SIMAS runtime."]; return; }
    if ([program->functions objectForKey:name]) { [SIMASRuntime throwException:@"DuplicateName" withReason:[NSString stringWithFormat:@"Function %@ already exists.", name]]; return; }
    self->argumentCount = (int)[[args objectAtIndex:1] intValue] < 0 ? 0 : (int)[[args objectAtIndex:1] intValue];
    self->name = [name copy];
    [program->functions setObject:self forKey:self->name];
}

- (void)end {
    [SIMASRuntime currentProgram]->programCounter = (int)self->location.location;
}

+ (void)returnFunction:(NSArray*)args {
    SIMASBlock *block = [[SIMASRuntime currentProgram]->stack lastObject];
    while (![block isKindOfClass:[SIMASFunction class]] && block) {
        [block cleanUp];
        block = [block parent];
    }
    if (block) [(SIMASFunction*)block ret:args];
    else {
        [SIMASRuntime throwException:@"IllegalReturn" withReason:@"A return call was made outside of a function. Return calls MUST be made inside functions."];
    }
}

- (void)ret:(NSArray*)args {
    SIMASProgram *program = [SIMASRuntime currentProgram];
    SIMASVariable *newVar = nil;
    if ([args count] == 2) {
        newVar = [SIMASVariable new];
        NSString *type = [[args objectAtIndex:0] lowercaseString];
        if ([type isEqualToString:@"v"]) [newVar setData:[[[[SIMASVariable findVariable:[args objectAtIndex:1]] data] copy] autorelease]];
        else {
            if (![[SIMASRuntime runtime]->registeredTypes objectForKey:type]) { [SIMASRuntime throwException:@"NonexistentType" withReason:[NSString stringWithFormat:@"Type %@ does not exist, thus cannot be used to convert.", type]]; return; }
            [newVar setData:[[[SIMASRuntime runtime]->registeredTypes objectForKey:type] fromString:[args objectAtIndex:1]]];
        }
        if (![newVar data]) {
            [newVar release];
            newVar = nil;
        }
    }
    program->programCounter = returnTo;
    SIMASBlock *block = [program->stack lastObject];
    while (self != block && block) {
        [block cleanUp];
        block = [block parent];
    }
    [self cleanUp];
    if (newVar) {
        NSString *name = [NSString stringWithFormat:@"$%@", self->name];
        [[program->stack lastObject] deleteVariable:name];
        [[program->stack lastObject] addVariable:newVar forName:name];
        [newVar release];
    }
}

- (void)cleanUp {
    [self->arguments removeAllObjects];
    self->returnTo = 0;
    [[SIMASRuntime currentProgram]->stack removeObject:self];
}

- (void)doThings:(NSArray*)args {
    [SIMASRuntime currentProgram]->programCounter += (int)self->location.length;
}

+ (int)argumentMin { return 2; }
+ (int)argumentMax { return 2; }
+ (BOOL)canBeNested { return NO; }
+ (NSString*)identifier { return @"fun"; }

+ (void)jump:(NSArray*)args {
    NSString *name = [args objectAtIndex:0];
    SIMASProgram *program = [SIMASRuntime currentProgram];
    SIMASFunction *function;
    if (!(function = [program->functions objectForKey:name])) { [SIMASRuntime throwException:@"IllegalFunction" withReason:[NSString stringWithFormat:@"Function %@ does not exist.", name]]; return; }
    if ([args count] != 1 + (function->argumentCount * 2)) {
        [SIMASRuntime throwException:@"IllegalArgumentCount" withReason:[NSString stringWithFormat:@"An improper number of arguments was passed to call to function %@ (expected %d, recieved %d)", name, 1 + (function->argumentCount * 2), (int)[args count]]];
        return;
    }
    NSMutableArray *newArgs = [NSMutableArray new];
    for (int i = 0; i < function->argumentCount; i++) {
        NSString *typeString = [[args objectAtIndex:i * 2 + 1] lowercaseString];
        NSString *nameString = [args objectAtIndex:i * 2 + 2];
        if ([typeString isEqualToString:@"v"]) {
            SIMASVariable *newVar = [SIMASVariable new];
            [newVar setData:[[[[SIMASVariable findVariable:nameString] data] copy] autorelease]];
            [newArgs addObject:newVar];
            [newVar release];
        } else if ([typeString isEqualToString:@"p"]) {
            [newArgs addObject:[[SIMASVariable findVariable:nameString] makePointer]];
        } else {
            if (![[SIMASRuntime runtime]->registeredTypes objectForKey:typeString]) { [SIMASRuntime throwException:@"NonexistentType" withReason:[NSString stringWithFormat:@"Type %@ does not exist, thus cannot be used to convert.", typeString]]; return; }
            SIMASVariable *newVar = [SIMASVariable new];
            [newVar setData:[[[SIMASRuntime runtime]->registeredTypes objectForKey:typeString] fromString:nameString]];
            [newArgs addObject:newVar];
            [newVar release];
        }
    }
    [function->arguments setArray:newArgs];
    for (int i = 0, count = (int)[newArgs count]; i < count; i++) {
        [function addVariable:[function->arguments objectAtIndex:i] forName:[NSString stringWithFormat:@"$%d", i]];
    }
    [newArgs release];
    [program->stack addObject:function];
    function->returnTo = program->programCounter;
    program->programCounter = (int)function->location.location;
}

- (void)dealloc {
    [self->name release];
    [self->arguments release];
    [super dealloc];
}
@end

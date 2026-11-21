//
//  SIMASBlock.m
//  simas_runtime
//
//  Created by Xander Gomez on 11/20/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//

#import "SIMASBlock.h"

@implementation SIMASBlock
- (id)init {
    if ((self = [super init])) {
        self->labels = [NSMutableDictionary new];
        self->variables = [NSMutableDictionary new];
        self->childNodes = [NSMutableDictionary new];
        self->instantiatedStructs = [NSMutableDictionary new];
    }
    return self;
}

+ (SIMASBlock*)processBlocksForRange:(NSRange)range inInstructions:(NSArray *)instructions exception:(SIMASException**)ex {
    SIMASException *buffer = nil;
    SIMASBlock *block = [[self blockWithLocation:range] autorelease];
    BOOL isRoot = [[self identifier] isEqualToString:@""];
    if (!ex) { // sentinel to see that this is the root
        ex = &buffer;
    }
    for (int i = !isRoot; i < range.length; i++) {
        SIMASInstruction *inst = [instructions objectAtIndex:(range.location + i)];
        Class blockClass = Nil;
        block->location.length = i;
        if (![[inst->name lowercaseString] isEqualToString:@"end"] && (([[block class] usesBlacklist] && [[[block class] blacklist] containsObject:inst->operation]) || ([[block class] usesWhitelist] && ![[[block class] whitelist] containsObject:inst->operation]))) {
            *ex = [SIMASException makeWithException:@"ForbiddenInstruction" andReason:@"The provided instruction is not allowed from running in this block." withInstruction:inst];
            goto killTheTree;
        } else if ((blockClass = [[SIMASRuntime runtime]->registeredBlocks objectForKey:[inst->name lowercaseString]])) {
            if (![blockClass canBeNested] && !isRoot) {
                *ex = [SIMASException makeWithException:@"IllegalNest" andReason:[NSString stringWithFormat:@"Blocks of type %@ cannot be nested in other blocks.", [self identifier]] withInstruction:inst];
                goto killTheTree;
            }
            NSRange newRange = NSMakeRange(range.location + i, range.length - i);
            SIMASBlock *newBlock = [blockClass processBlocksForRange:newRange inInstructions:instructions exception:ex];
            if (!newBlock && *ex) {
                goto killTheTree;
            } else if (newBlock) {
                [block addNode:newBlock];
                i += newBlock->location.length;
            }
            blockClass = nil;
        } else if ([[inst->name lowercaseString] isEqualToString:@"end"]) {
            if (isRoot) {
                *ex = [SIMASException makeWithException:@"ExtraneousEnd" andReason:@"An end instruction has occured without a block." withInstruction:inst];
                goto killTheTree;
            } else if (![[[[inst->arguments objectAtIndex:0] string] lowercaseString] isEqualToString:[self identifier]]) {
                *ex = [SIMASException makeWithException:@"MismatchedEndings" andReason:[NSString stringWithFormat:@"A block of type %@ was improperly ended with an ending of type %@", [self identifier], [[inst->arguments objectAtIndex:0] string]] withInstruction:inst];
                goto killTheTree;
            }
            [block reg:((SIMASInstruction*)[[SIMASRuntime currentProgram]->instructions objectAtIndex:block->location.location])->arguments withException:ex];
            if (*ex) { (*ex)->instruction = inst; goto killTheTree; }
            return block;
        }
    }
    if (!isRoot) {
        *ex = [SIMASException makeWithException:@"UnendingBlock" andReason:@"A block was not properly paired with an \"end\" instruction." withInstruction:[instructions objectAtIndex:block->location.location]];
        goto killTheTree;
    } else {
        block->location.length = range.length;
    }
    return block;
    
killTheTree:
    if (buffer) [SIMASRuntime throwException:buffer];
    return nil;
}
+ (id)blockWithLocation:(NSRange)location { SIMASBlock *block = [[self class] new]; block->location = location; return block; }
+ (NSString*)identifier { return @""; }
+ (BOOL)canBeNested { return YES; }
+ (int)argumentMin { return 0; }
+ (int)argumentMax { return 0; }
+ (SIMASArgumentClassifier*)argClassifiers { return NULL; }
+ (BOOL)usesWhitelist {
    return NO;
}
+ (BOOL)usesBlacklist {
    return YES;
}
+ (NSMutableSet*)whitelist {
    NSMutableDictionary *listDict = [[[NSThread currentThread] threadDictionary] objectForKey:@"blockWhitelists"];
    NSMutableSet *list = [listDict objectForKey:[self class]];
    if (!list) {
        [listDict setObject:(list = [[NSMutableSet new] autorelease]) forKey:(id<NSCopying>)[self class]];
        [self initWhitelistData];
    }
    return list;
}
+ (NSMutableSet*)blacklist {
    NSMutableDictionary *listDict = [[[NSThread currentThread] threadDictionary] objectForKey:@"blockBlacklists"];
    NSMutableSet *list = [listDict objectForKey:[self class]];
    if (!list) {
        [listDict setObject:(list = [[NSMutableSet new] autorelease]) forKey:(id<NSCopying>)[self class]];
        [self initBlacklistData];
    }
    return list;
}
+ (void)initWhitelistData {
    return;
}
+ (void)initBlacklistData {
    NSMutableSet *set = [self blacklist]; // slightly recursive but it's fine since the second pass will have had it alloc'd and hence it wont double up on this.
    [set addObject:[[[SIMASRuntime runtime]->registeredOperations objectForKey:@""] objectForKey:@"ret"]];
}
- (void)reg:(NSArray*)args withException:(SIMASException**)ex { return; }
- (void)addNode:(SIMASBlock*)node { [self->childNodes setObject:node forKey:[NSNumber numberWithInt:(int)node->location.location]]; node->parentNode = self; }
- (void)doThings:(NSArray *)args { [self enter]; }
- (void)addVariable:(SIMASVariable *)var forName:(NSString *)name { [self->variables setObject:var forKey:name]; }
- (SIMASVariable*)getVar:(NSString *)name { return [self->variables objectForKey:name]; }
- (void)deleteVariable:(NSString*)name { [self->variables removeObjectForKey:name]; }
- (void)end { [self cleanUp]; }
- (void)enter { [[SIMASRuntime currentProgram]->stack addObject:self]; [self clearItems]; }
- (SIMASBlock*)clone {
    SIMASBlock *new = [[[self class] new] autorelease];
    [new->childNodes setDictionary:self->childNodes];
    [new->labels setDictionary:self->labels];
    new->location = self->location;
    new->isClone = YES;
    new->parentNode = self->parentNode;
    return new;
}
- (SIMASBlock*)recursivelyClone {
    SIMASBlock *new = [self clone];
    [new->childNodes release];
    new->childNodes = [NSMutableDictionary new];
    NSArray *childrenKeys = [self->childNodes allKeys], *children = [self->childNodes objectsForKeys:childrenKeys notFoundMarker:[NSNull null]];
    for (int i = 0, count = (int)[children count]; i < count; i++) {
        SIMASBlock *newChild = [[children objectAtIndex:i] recursivelyClone];
        [new->childNodes setObject:newChild forKey:[childrenKeys objectAtIndex:i]];
        newChild->parentNode = new;
    }
    return new;
}
- (void)clearItems { [self->variables removeAllObjects]; }
- (void)cleanUp { [self clearItems]; [self removeFromStack]; }
- (SIMASBlock*)findNode:(int)pc { return [self->childNodes objectForKey:[NSNumber numberWithInt:pc]]; }
- (NSNumber*)programCounterForLabel:(NSString*)label { return [self->labels objectForKey:label]; }
- (SIMASBlock*)parent { return self->parentNode; }
- (id)getStruct:(NSString*)name { return [self->instantiatedStructs objectForKey:name]; }
- (void)preprocessLabels:(NSMutableArray*)instructions {
    for (int i = ![[[self class] identifier] isEqualToString:@""]; i < self->location.length && ![[SIMASRuntime runtime] isExcepted]; i++) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSNumber *number = [NSNumber numberWithInt:(int)(self->location.location + i)];
        SIMASBlock *block = [self->childNodes objectForKey:number];
        if (block) {
            [block preprocessLabels:instructions];
            i += block->location.length;
            [pool release];
            continue;
        }
        SIMASInstruction *inst = [instructions objectAtIndex:(int)(self->location.location + i)];
        if (inst->operation->functionPointer == labelNop) {
            NSString *name = [[inst->arguments objectAtIndex:0] string];
            if ([self->labels objectForKey:name]) {
                [SIMASRuntime throwException:@"DuplicateLabel" withReason:[NSString stringWithFormat:@"Label '%@' is already defined.", name] withInstruction:inst];
            }
            SIMASException *ex = [SIMASRuntime validateName:name];
            if (ex) {
                ex->instruction = inst;
                [SIMASRuntime throwException:ex];
            }
            [self->labels setObject:[NSNumber numberWithInt:(int)(self->location.location + i)] forKey:name];
        }
        [pool release];
    }
}
- (void)removeFromStack {
    NSMutableArray *stack = [SIMASRuntime currentProgram]->stack;
    for (int idx = (int)[stack count] - 1; idx >= 0; idx--) {
        if ([stack objectAtIndex:idx] == self) {
            [stack removeObjectAtIndex:idx];
            return;
        }
    }
}
- (void)dealloc {
    [self->variables release];
    [self->childNodes release];
    [self->labels release];
    [self->instantiatedStructs release];
    [super dealloc];
}
@end

@implementation SIMASBlockGeneric
+ (NSString*)identifier { return @"block"; }
@end

@implementation SIMASStruct
+ (NSString*)identifier { return @"struct"; }
+ (BOOL)canBeNested { return NO; }
+ (int)argumentMin { return 1; }
+ (int)argumentMax { return 1; }
+ (BOOL)usesWhitelist { return YES; }
+ (BOOL)usesBlacklist { return NO; }
+ (NSMutableSet*)whitelist {
    NSMutableSet *set = [NSMutableSet setWithSet:[SIMASRuntime runtime]->typeSet];
    [set addObject:[[[SIMASRuntime runtime]->registeredOperations objectForKey:@""] objectForKey:@"new"]];
    return set;
}
- (void)reg:(NSArray*)args withException:(SIMASException**)ex { // mmmm sketchy as fuck yum
    SIMASProgram *prog = [SIMASRuntime currentProgram];
    if ([prog->structures objectForKey:[args objectAtIndex:0]]) {
        *ex = [SIMASException makeWithException:@"StructureRedefinition" andReason:[NSString stringWithFormat:@"Structure %@ is already defined.", [args objectAtIndex:0]]];
        return;
    }
    if ((*ex = [SIMASRuntime validateName:[[args objectAtIndex:0] string]])) return;
    [prog->structures setObject:self forKey:[args objectAtIndex:0]];
    NSRange range = self->location;
    range.length -= 1;
    range.location += 1;
    NSArray *insts = [prog->instructions subarrayWithRange:range];
    if (![insts count]) {
        *ex = [SIMASException makeWithException:@"EmptyStructure" andReason:[NSString stringWithFormat:@"Structure %@ is empty.", [args objectAtIndex:0]]];
        return;
    }
    self->instructions = [insts retain];
    self->name = [[args objectAtIndex:0] copy];
}
- (void)doThings:(NSArray*)args {
    [SIMASRuntime currentProgram]->programCounter += (int)self->location.length;
}
+ (void)spawn:(NSArray*)args {
    SIMASException *nameValidation = [SIMASRuntime validateName:[[args objectAtIndex:1] string]];
    if (nameValidation) {
        [SIMASRuntime throwException:nameValidation];
        return;
    }
    SIMASStruct *newStruct = [[SIMASStruct new] autorelease];
    SIMASStruct *sourceStruct = [[SIMASRuntime currentProgram]->structures objectForKey:[[args objectAtIndex:0] string]];
    if (!sourceStruct) {
        [SIMASRuntime throwException:@"NonexistentStructure" withReason:[NSString stringWithFormat:@"Structure \"%@\" is not a valid structure.", [[args objectAtIndex:0] string]]];
        return;
    }
    [[SIMASRuntime currentProgram]->stack addObject:newStruct];
    int oldPC = [SIMASRuntime currentProgram]->programCounter;
    int *pc = &[SIMASRuntime currentProgram]->programCounter;
    *pc = (int)sourceStruct->location.location + 1;
    for (int i = 0, count = (int)[sourceStruct->instructions count]; i < count && ![[SIMASRuntime runtime] isExcepted]; i++) {
        if ([[[((SIMASInstruction*)[sourceStruct->instructions objectAtIndex:i])->arguments objectAtIndex:0] string] isEqualToString:sourceStruct->name]) {
            [SIMASRuntime throwException:@"RecursiveStructure" withReason:@"You cannot contain a structure within itself."];
            return;
        }
        [[sourceStruct->instructions objectAtIndex:i] execute];
        (*pc)++;
    }
    *pc = oldPC;
    [[SIMASRuntime currentProgram]->stack removeLastObject];
    [((SIMASStruct*)[[SIMASRuntime currentProgram]->stack lastObject])->instantiatedStructs setObject:newStruct forKey:[[args objectAtIndex:1] string]];
}
+ (SIMASStruct*)findStruct:(NSString*)name {
    SIMASStruct *struc = nil;
    SIMASBlock *block = [[SIMASRuntime currentProgram]->stack lastObject];
    while (!(struc = [block->instantiatedStructs objectForKey:name]) && (block = [block parent]));
    return struc;
}
- (void)dealloc {
    [self->instructions release];
    [self->name release];
    [super dealloc];
}
@end

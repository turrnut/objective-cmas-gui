//
//  SIMASRuntime.m
//  objectivismas
//
//  Created by Xander Gomez on 9/6/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  I CAN'T SEE YOUR SOUL-SOUL THROUGH YOUR EYES
//  THE CRYING WALLS OF SLIDING ARCHITECTURE
//  KIDNAPPED BY THE LIKES OF PURE CONJECTURE
//  UPHOLSTERY-LOVING MEN
//  ALL DWELLING IN THE WELLS
//  KIDNAPPED BY THE LIKES OF PURE CONJECTURE
//  THEY'RE IN MY FUCKING WALLS HELP
//  I HAVE NOT SLEPT FOR 2 DAYS SINCE I STARTED WRITING THIS
//  THE CRYING WALLS OF SLIDING ARCHITECTURE ARE REAL
//  ---...---
//
//  SYSTEM OF A DOWN - THIS COCAINE MAKES ME FEEL LIKE I'M ON THIS SONG

#import "SIMASRuntime.h"
#import "SIMASFunction.h"
#import <pthread.h>

SIMASFUNC(labelNop) { return; }
SIMASFUNC(importNop) { return; }
SIMASFUNC(utiliseNop) { return; }

NSString *formatEscapes(NSString* str) {
    NSMutableString *string = [[str mutableCopy] autorelease];
    NSArray *formats = [NSArray arrayWithObjects:@"\\\"", @"\"", @"\\n", @"\n", @"\\t", @"\t", @"\\r", @"\r", @"\\\\", @"\\", nil];
    for (int i = 0; i < [formats count]; i += 2) [string replaceOccurrencesOfString:[formats objectAtIndex:i] withString:[formats objectAtIndex:i + 1] options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    return string;
}

NSString *unformatEscapes(NSString* str) {
    NSMutableString *string = [[str mutableCopy] autorelease];
    NSArray *formats = [NSArray arrayWithObjects:@"\\\\", @"\\", @"\\\"", @"\"", @"\\n", @"\n", @"\\t", @"\t", @"\\r", @"\r", nil];
    for (int i = 0; i < [formats count]; i += 2) [string replaceOccurrencesOfString:[formats objectAtIndex:i + 1] withString:[formats objectAtIndex:i] options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    return string;
}

static int countBackslashes(NSString* string) {
    if ([string length] < 1) return 0;
    int backSlashes = 0;
    for (int i = (int)[string length] - 1; i >= 0; i--) {
        if ([string characterAtIndex:i] == '\\') backSlashes++;
        else return backSlashes;
    }
    return backSlashes;
}

NSArray *tokeniseStringExcludingQuotes(NSString* str, NSCharacterSet* charSet) {
    NSMutableArray *objects = [[str componentsSeparatedByString:@"\""] mutableCopy];
    NSMutableArray *quoted = [NSMutableArray new];
    int *quoteIndexes = (int*)malloc([objects count] * sizeof(int));
    memset(quoteIndexes, 0, [objects count] * sizeof(int));
    int index = 0;
    BOOL isInQuotes = NO;
    while ([objects count]) {
        NSMutableString *string = [[objects objectAtIndex:0] mutableCopy];
        [objects removeObjectAtIndex:0];
        int backSlashes = 0; BOOL isEvenBackslashes = NO;
        if (![string length] && [objects count] && isInQuotes) {
            quoteIndexes[index] = 1;
            [objects removeObjectAtIndex:0];
        } else if (isInQuotes) {
            while ([objects count]) {
                isEvenBackslashes = !((backSlashes = countBackslashes(string)) % 2);
                quoteIndexes[index] = 1;
                if (!isEvenBackslashes && backSlashes) {
                    [string appendString:@"\""];
                    [string appendString:[objects objectAtIndex:0]];
                    [objects removeObjectAtIndex:0];
                    continue;
                }
                break;
            }
        }
        isInQuotes = !isInQuotes;
        [quoted addObject:string];
        [string release];
        index += 1;
    }
    [objects release];
    objects = [NSMutableArray new];
    for (int i = 0; i < [quoted count]; i++) {
        NSString *string = [quoted objectAtIndex:i];
        if (!quoteIndexes[i]) {
            NSMutableArray *sliced = [[string componentsSeparatedByCharactersInSet:charSet] mutableCopy];
            for (int ii = 0; ii < [sliced count]; ii++) {
                [sliced replaceObjectAtIndex:ii withObject:[[sliced objectAtIndex:ii] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                if ([[sliced objectAtIndex:ii] length] < 1) [sliced removeObjectAtIndex:ii--];
            }
            if ([sliced count]) [objects addObjectsFromArray:sliced];
            [sliced release];
        } else {
            [objects addObject:[NSString stringWithFormat:@"\"%@\"", string]];
        }
    }
    [quoted release];
    free(quoteIndexes);
    return [objects autorelease];
}

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
    SIMASBlock *new = [[self class] new];
    new->childNodes = [self->childNodes retain];
    new->labels = [self->labels retain];
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
- (void)cleanUp { [self removeFromStack]; [self clearItems]; if (self->isClone) [self release]; }
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

@implementation SIMASArgument
+ (id)argumentForString:(NSString*)str {
    SIMASArgument *arg = [SIMASArgument new];
    double doubleTest = 0.0;
    NSScanner *scan = [NSScanner scannerWithString:str];
    arg->argument = [str copy];
    if (![str length]) arg->classifier = SIMASArgumentGenericConstant;
    else if ([[SIMASRuntime runtime]->registeredTypes objectForKey:[str lowercaseString]]) arg->classifier = SIMASArgumentTypeName;
    else if ([[str lowercaseString] isEqualToString:@"in"]) arg->classifier = SIMASArgumentInput;
    else if ([str length] > 1 && [str characterAtIndex:0] == '"' && [str characterAtIndex:([str length] - 1)] == '"') {
        arg->classifier = SIMASArgumentString;
        [arg->argument release];
        arg->argument = [[str substringWithRange:NSMakeRange(1, [str length] - 2)] copy];
    }
    else if ([[str lowercaseString] isEqualToString:@"true"] || [[str lowercaseString] isEqualToString:@"false"]) arg->classifier = SIMASArgumentBoolean;
    else if ([scan scanDouble:&doubleTest] && [scan isAtEnd]) arg->classifier = SIMASArgumentNumber;
    else arg->classifier = SIMASArgumentVariableName;
    return arg;
}
+ (id)argumentForString:(NSString*)str fallback:(SIMASArgumentClassifier)fallback {
    SIMASArgument *arg = [self argumentForString:str];
    if (arg->classifier == SIMASArgumentVariableName) arg->classifier = [self standardClassification:fallback];
    return arg;
}
+ (id)argumentForString:(NSString*)str forOperation:(SIMASOperation*)op forIndex:(int)index {
    SIMASArgument *arg = [SIMASArgument new];
    arg->argument = [str copy];
    arg->classifier = [self standardClassification:op->classifications[index]];
    if (arg->classifier == SIMASArgumentString && [str length] > 1 && [str characterAtIndex:0] == '"' && [str characterAtIndex:([str length] - 1)] == '"') {
        [arg->argument release]; arg->argument = [[str substringWithRange:NSMakeRange(1, [str length] - 2)] copy];
    }
    return arg;
}
+ (SIMASArgumentClassifier)standardClassification:(SIMASArgumentClassifier)src {
    return src ^ (src & (SIMASArgumentUseGeneric | SIMASArgumentUseThis | SIMASArgumentUseAsFallback | SIMASArgumentStrictMatch));
}
+ (NSString*)nameForClassifier:(SIMASArgumentClassifier)classifier {
    switch (classifier) {
        case SIMASArgumentString: return @"string";
        case SIMASArgumentNumber: return @"number";
        case SIMASArgumentBoolean: return @"boolean";
        case SIMASArgumentInput: return @"input";
        case SIMASArgumentTypeName: return @"type name";
        case SIMASArgumentVariableName: return @"variable name";
        default: return @"generic constant";
    }
}
+ (NSString*)namesForClassifiers:(SIMASArgumentClassifier)classifiers {
    SIMASArgumentClassifier current = 1;
    NSMutableArray *objs = [NSMutableArray new];
    NSMutableString *str = [[NSMutableString new] autorelease];
    while (current < SIMASArgumentThing) {
        if (current & classifiers) [objs addObject:[self nameForClassifier:current]];
        current <<= 1;
    }
    for (int i = 0; i < [objs count]; i++) {
        [str appendString:[objs objectAtIndex:i]];
        if (i + 2 == [objs count]) [str appendString:@", or "];
        else if (i + 1 < [objs count]) [str appendString:@", "];
    }
    return str;
}
- (NSString*)string {
    return self->argument;
}
- (SIMASArgumentClassifier)classification {
    return self->classifier;
}
- (void)dealloc {
    [self->argument release];
    [super dealloc];
}
- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
    if (![self respondsToSelector:selector] && [self->argument respondsToSelector:selector]) return [self->argument methodSignatureForSelector:selector];
    else return [super methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([self->argument respondsToSelector:[anInvocation selector]]) [anInvocation invokeWithTarget:self->argument];
    else [super forwardInvocation:anInvocation];
}
- (SIMASData*)createData {
    switch (self->classifier) {
        case SIMASArgumentBoolean: return [SIMASBoolean booleanWithString:self->argument];
        case SIMASArgumentNumber: return [SIMASNumber numberWithString:self->argument];
        case SIMASArgumentString: return [SIMASString stringWithString:self->argument];
        default: return nil;
    }
}

- (NSUInteger)length { // change this to int on older shit
    return [self->argument length];
}

- (unichar)characterAtIndex:(NSUInteger)index { // same here
    return [self->argument characterAtIndex:index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range {
    [self->argument getCharacters:buffer range:range];
}
@end

@implementation SIMASOperation
- (id)init {
    self = [super init];
    if (self) {
        self->maximumArguments = -1;
    }
    return self;
}
+ (SIMASOperation*)makeWithFunction:(void (*)(id, SEL, NSArray*))func {
    SIMASOperation *newOp = [SIMASOperation new];
    newOp->functionPointer = func;
    newOp->targetGetter = nullTarget;
    newOp->selectorGetter = nullSelector;
    return [newOp autorelease];
}
+ (SIMASOperation*)makeWithFunction:(void (*)(id, SEL, NSArray*))func withTargetGetter:(id (*)(NSArray*))target andSelectorGetter:(SEL (*)(void))selector {
    SIMASOperation *newOp = [SIMASOperation makeWithFunction:func];
    newOp->targetGetter = target;
    newOp->selectorGetter = selector;
    return newOp;
}
+ (SIMASOperation*)makeWithFunction:(void (*)(id, SEL, NSArray *))func withTarget:(id)target andSelector:(SEL)selector {
    SIMASOperation *newOp = [SIMASOperation makeWithFunction:func];
    newOp->target = target;
    newOp->selector = selector;
    return newOp;
}
- (void)setMaxArgs:(int)maximum { maximumArguments = maximum; }
- (void)setMinArgs:(int)minimum { minimumArguments = minimum; }
- (void)setArgRange:(int)minimum toMaximum:(int)maximum { minimumArguments = minimum; maximumArguments = maximum; };
- (void)setArgClassifiers:(SIMASArgumentClassifier *)classifications {
    self->classifications = malloc(sizeof(SIMASArgumentClassifier) * self->maximumArguments);
    memcpy(self->classifications, classifications, sizeof(SIMASArgumentClassifier) * self->maximumArguments);
}
- (void)dealloc {
    free(self->classifications);
    [super dealloc];
}
@end

@implementation SIMASInstruction
+ (id)instructionFromOperation:(SIMASOperation*)op {
    SIMASInstruction *newInstruction = [SIMASInstruction new];
    newInstruction->operation = op;
    return [newInstruction autorelease];
}
+ (id)instructionFromOperation:(SIMASOperation*)op withArguments:(NSArray*)arguments {
    SIMASInstruction *newInstruction = [self instructionFromOperation:op];
    NSMutableArray *args = [NSMutableArray new];
    for (int i = 0, count = (int)[arguments count]; i < count; i++) {
        SIMASArgumentClassifier classification = op->classifications ? op->classifications[i] : 0;
        SIMASArgument *arg = nil;
        switch (classification & (SIMASArgumentUseGeneric | SIMASArgumentUseThis | SIMASArgumentUseAsFallback)) {
            case SIMASArgumentUseThis:
                arg = [SIMASArgument argumentForString:[arguments objectAtIndex:i] forOperation:op forIndex:i];
                break;
            case SIMASArgumentUseAsFallback:
                arg = [SIMASArgument argumentForString:[arguments objectAtIndex:i] fallback:classification];
                break;
            default:
            case SIMASArgumentUseGeneric:
                arg = [SIMASArgument argumentForString:[arguments objectAtIndex:i]];
                break;
        }
        [args addObject:arg];
        [arg release];
        if (classification & SIMASArgumentStrictMatch && !([arg classification] & [SIMASArgument standardClassification:classification])) {
            [SIMASRuntime throwException:@"BadArgument" withReason:[NSString stringWithFormat:@"At index %d, received argument of %@, expected argument of %@. %@", i, [SIMASArgument nameForClassifier:[arg classification]], [SIMASArgument namesForClassifiers:[SIMASArgument standardClassification:classification]], (classification & SIMASArgumentTypeName) ? @"Please note that if you were trying to use a type name, the type you're looking for may not be registered." : @""] withSnideRemark:@"Perhaps read the documentation next time? Actual skill issue, btw"]; // holy fuck
            [[NSNotificationCenter defaultCenter] postNotificationName:@"InstructionFailed" object:[SIMASRuntime runtime] userInfo:[NSDictionary dictionaryWithObject:newInstruction forKey:@"instruction"]];
        }
    }
    newInstruction->arguments = [args copy];
    [args release];
    return newInstruction;
}

- (BOOL)isFunction:(SIMASFUNCTYPE)function {
    return self->operation->functionPointer == function;
}

- (void)execute {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"InstructionExecuted" object:[SIMASRuntime runtime] userInfo:[NSMutableDictionary dictionaryWithObject:self forKey:@"instruction"]];
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    self->operation->functionPointer(self->operation->target ? self->operation->target : self->operation->targetGetter(self->arguments), self->operation->selector ? self->operation->selector : self->operation->selectorGetter(), self->arguments);
    [pool release];
}

+ (void)preprocessImports:(NSMutableArray*)instructions {
    BOOL moreImports = NO;
    NSMutableSet *imports = [NSMutableSet new];
    do {
        moreImports = NO;
        int count = (int)[instructions count];
        for (int i = 0; i < count; i++) {
            SIMASInstruction *current = [instructions objectAtIndex:i];
            if (current->operation->functionPointer == importNop) {
                NSString *name = [current->arguments objectAtIndex:0];
                if ([imports containsObject:name]) {
                    [SIMASRuntime throwException:@"ImportFailed" withReason:[NSString stringWithFormat:@"The file %@ has already been imported.", name] withInstruction:current];
                    [imports release];
                    return;
                }
                [imports addObject:name];
                NSString *data = [NSString stringWithContentsOfFile:name encoding:NSASCIIStringEncoding error:nil];
                if (!data) {
                    [SIMASRuntime throwException:@"ImportFailed" withReason:[NSString stringWithFormat:@"The file %@ failed to import.", name] withInstruction:current];
                    [imports release];
                    return;
                }
                NSAutoreleasePool *pool = [NSAutoreleasePool new];
                NSMutableArray *newInstructions = [self parseInstructionsFromString:data];
                [instructions removeObjectAtIndex:i];
                [instructions insertObjects:newInstructions atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, [newInstructions count])]];
                [pool release];
                moreImports = YES;
            }
        }
    } while (moreImports);
    [imports release];
}

+ (NSMutableArray*)parseInstructionsFromString:(NSString*)string {
    NSMutableArray *instructionStrings = [NSMutableArray new];
    NSMutableArray *ranges = [[NSMutableArray new] autorelease];
    NSMutableString *buffer = [string mutableCopy];
    NSRange lastRange = NSMakeRange(0, 0);
    while ([buffer length]) {
        NSRange rangeOfInstruction = [buffer rangeOfString:@";"];
        if (rangeOfInstruction.location == NSNotFound) break;
        NSRange originalRange = NSMakeRange(NSMaxRange(lastRange), 0);
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSMutableString *instruction = [[NSMutableString new] autorelease];
        BOOL inQuotes = NO;
        do {
            int backslashStreak = 0;
            for (int i = 0; i < rangeOfInstruction.location; i++) {
                unichar character = [buffer characterAtIndex:i];
                if (character == '"' && !(backslashStreak % 2)) inQuotes = !inQuotes;
                if (character == '\\' && inQuotes) ++backslashStreak;
                else backslashStreak = 0;
            }
            if (inQuotes) {
                rangeOfInstruction.length = rangeOfInstruction.location + 1;
                rangeOfInstruction.location = 0;
                originalRange.length += rangeOfInstruction.length;
                [instruction appendString:[buffer substringWithRange:rangeOfInstruction]];
                [buffer deleteCharactersInRange:rangeOfInstruction];
                rangeOfInstruction = [buffer rangeOfString:@";"];
            }
        } while (inQuotes && [buffer length]);
        rangeOfInstruction.length = rangeOfInstruction.location;
        rangeOfInstruction.location = 0;
        if ([buffer length] < rangeOfInstruction.length) { [pool release]; break; }
        [instruction appendString:[buffer substringWithRange:rangeOfInstruction]];
        if ([buffer length] >= rangeOfInstruction.length + 1) rangeOfInstruction.length += 1;
        originalRange.length += rangeOfInstruction.length;
        [buffer deleteCharactersInRange:rangeOfInstruction];
        [instructionStrings addObject:instruction];
        lastRange = originalRange;
        [ranges addObject:[NSValue valueWithRange:originalRange]];
        [pool release];
    }
    [buffer release];
    
    // phase 2: tokenisation
    NSMutableArray *tokens = [[NSMutableArray new] autorelease];
    for (int i = 0; i < [instructionStrings count]; i++) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSMutableCharacterSet *characters = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *str = [[instructionStrings objectAtIndex:i] stringByTrimmingCharactersInSet:characters];
        if ([str length] && [str characterAtIndex:0] == '@') { [instructionStrings removeObjectAtIndex:i]; [ranges removeObjectAtIndex:i--]; [pool release]; continue; }
        NSArray *tokenised = tokeniseStringExcludingQuotes(str, characters);
        if ([tokenised count] && [[tokenised objectAtIndex:0] length]) [tokens addObject:tokenised];
        [pool release];
    }
    [instructionStrings release];
    
    
    // phase 3: turning into instruction
    NSMutableArray *instructions = [[NSMutableArray new] autorelease];
    while ([tokens count]) {
        NSMutableArray *string = [[tokens objectAtIndex:0] mutableCopy]; // we love accidentally shadowing our own parameters, oh well, it works so /shrug
        NSRange range = [[ranges objectAtIndex:0] rangeValue];
        [ranges removeObjectAtIndex:0];
        [tokens removeObjectAtIndex:0];
        while ([string count] && [[[string objectAtIndex:0] lowercaseString] isEqualToString:@"please"]) [string removeObjectAtIndex:0];
        if (![string count]) { [string release]; continue; }
        SIMASOperation *operation;
        if ([[[string objectAtIndex:0] lowercaseString] isEqualToString:@"utilising"]) {
            if ([string count] == 2) [SIMASRuntime throwException:@"IllegalArgumentCount"
                                                       withReason:[NSString stringWithFormat:@"The provided instruction does not contain enough arguments (either 1 or 3, got 2) for instruction utilise."]
                                                  withSnideRemark:@"like... utilising it as WHAT, buddy? \"as\" and then jack shit doesn't tell me ANYTHING i need to know, after all"];
            NSString *libName = [string objectAtIndex:1];
            NSString *prefix = [string count] == 3 && [[[string objectAtIndex:1] lowercaseString] isEqualToString:@"as"] ? [string objectAtIndex:2] : @"";
            NSBundle *bundle = [NSBundle bundleWithPath:libName];
            if (bundle && ![[SIMASRuntime runtime] isExcepted]) [[SIMASRuntime runtime] loadLibrary:bundle withPrefix:[prefix lowercaseString]];
            [string release];
            if ([[SIMASRuntime runtime] isExcepted]) return nil;
            continue;
        }
        NSString *name = nil, *prefix = nil;
        if ((operation = [[[SIMASRuntime runtime]->registeredOperations objectForKey:@""] objectForKey:[[string objectAtIndex:0] lowercaseString]]) == nil) {
            NSMutableDictionary *prefixMap = [[SIMASRuntime runtime]->registeredOperations objectForKey:[[string objectAtIndex:0] lowercaseString]];
            if (!prefixMap || [string count] < 2 || (operation = [prefixMap objectForKey:[[string objectAtIndex:1] lowercaseString]]) == nil) {
                [SIMASRuntime throwException:@"IllegalInstruction" withReason:[NSString stringWithFormat:@"Instruction '%@' is not a recognised instruction by the SIMAS runtime.", [string objectAtIndex:0]]];
                [string release]; return nil;
            }
            prefix = [string objectAtIndex:0];
            [string removeObjectAtIndex:0];
        }
        name = [string objectAtIndex:0];
        [string removeObjectAtIndex:0];
        for (int i = 0; i < [string count]; i++) [string replaceObjectAtIndex:i withObject:formatEscapes([string objectAtIndex:i])];
        SIMASInstruction *instruction = [SIMASInstruction instructionFromOperation:operation withArguments:string];
        if (instruction == nil) { [string release]; continue; }
        instruction->name = [name retain];
        instruction->prefix = [prefix retain];
        instruction->rangeOfInstruction = range;
        int argCount = (int)[instruction->arguments count];
        [string release];
        if ([[SIMASRuntime runtime] isExcepted]) return nil;
        if (argCount > operation->maximumArguments && operation->maximumArguments >= 0) {
            [SIMASRuntime throwException:@"IllegalArgumentCount"
                              withReason:[NSString stringWithFormat:@"The provided instruction cointains too many arguments (maximum %d, got %d) for instruction %@", operation->maximumArguments, argCount, instruction->name]
                         withInstruction:instruction];
            return nil;
        } else if (argCount < operation->minimumArguments) {
            [SIMASRuntime throwException:@"IllegalArgumentCount"
                              withReason:[NSString stringWithFormat:@"The provided instruction does not contain enough arguments (minimum %d, got %d) for instruction %@", operation->minimumArguments, argCount, instruction->name]
                         withInstruction:instruction];
            return nil;
        }
        if (instruction == nil) continue;
        [instructions addObject:instruction];
    }
    return instructions;
}

- (NSString*)stringValue {
    NSMutableArray *tokens = [NSMutableArray new];
    NSMutableString *fullInstruction = [NSMutableString new];
    if (prefix) [tokens addObject:prefix];
    [tokens addObject:name];
    [tokens addObjectsFromArray:arguments];
    while ([tokens count]) {
        BOOL isArgument = [[tokens objectAtIndex:0] isKindOfClass:[SIMASArgument class]];
        NSString *token = [tokens objectAtIndex:0];
        [tokens removeObjectAtIndex:0];
        BOOL wrapInQuotes = isArgument && [(SIMASArgument*)token classification] == SIMASArgumentString;
        if (wrapInQuotes) [fullInstruction appendString:@"\""];
        [fullInstruction appendString:token];
        if (wrapInQuotes) [fullInstruction appendString:@"\""];
        
        if (![tokens count]) [fullInstruction appendString:@";"];
        else [fullInstruction appendString:@" "];
    }
    [tokens release];
    return [fullInstruction autorelease];
}

- (void)dealloc {
    [arguments release];
    [name release];
    [prefix release];
    [super dealloc];
}
@end

@implementation SIMASProgram
- (id)init {
    self = [super init];
    if (self) {
        self->functions = [NSMutableDictionary new];
        self->instructions = [NSMutableArray new];
        self->stack = [NSMutableArray new];
        self->structures = [NSMutableDictionary new];
    }
    return self;
}

+ (SIMASProgram*)loadFromString:(NSString*)string {
    SIMASProgram *newProgram = [SIMASProgram new];
    [newProgram->instructions setArray:[SIMASInstruction parseInstructionsFromString:string]];
    return [newProgram autorelease];
}

- (void)dealloc {
    [self->functions release];
    [self->instructions release];
    [self->stack release];
    [self->baseBlock release];
    [self->structures release];
    [super dealloc];
}
@end

@implementation SIMASException
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason {
    SIMASException *ex = [SIMASException new];
    ex->exception = [exception copy];
    ex->reason = [reason copy];
    return [ex autorelease];
}
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason withRemark:(NSString*)remark {
    SIMASException *ex = [self makeWithException:exception andReason:reason];
    ex->remark = [remark copy];
    return ex;
}
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason withInstruction:(SIMASInstruction*)instruction {
    SIMASException *ex = [self makeWithException:exception andReason:reason];
    ex->instruction = instruction;
    return ex;
}
- (void)dealloc {
    [self->exception release];
    [self->reason release];
    [self->remark release];
    [super dealloc];
}
@end

SIMASCLASSMETHOD(SIMASFunction)

SIMASFUNC(endBlock) {
    [self end];
}

id getBlock(NSArray* args) {
    return [[[SIMASRuntime currentProgram]->stack lastObject] findNode:[SIMASRuntime currentProgram]->programCounter];
}

id getStackFrame(NSArray* args) {
    return [[SIMASRuntime currentProgram]->stack lastObject];
}

@implementation SIMASRuntime
- (void)stdoutPrint:(NSString*)string {
    printf("%s", [string UTF8String]);
}

- (void)errPrint:(NSString*)string {
    NSLog(@"%@", string);
}

- (NSString*)stdinput {
    return [[[[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] availableData] encoding:NSASCIIStringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (id)init {
    self = [super init];
    if (self && ![[[NSThread currentThread] threadDictionary] objectForKey:@"runtime"]) {
        NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        [threadDict setObject:self forKey:@"runtime"];
        [threadDict setObject:[[NSMutableDictionary new] autorelease] forKey:@"conversions"];
        [threadDict setObject:[[NSMutableDictionary new] autorelease] forKey:@"blockBlacklists"];
        [threadDict setObject:[[NSMutableDictionary new] autorelease] forKey:@"blockWhitelists"];
        registeredClasses = [NSMutableDictionary new];
        registeredTypes = [NSMutableDictionary new];
        registeredOperations = [NSMutableDictionary new];
        registeredBlocks = [NSMutableDictionary new];
        operationSet = [NSMutableSet new];
        typeSet = [NSMutableSet new];
        [SIMASBoolean registerToRuntime];
        [SIMASNumber registerToRuntime];
        [SIMASString registerToRuntime];
        SIMASOperation *thing;
        thing = [SIMASOperation makeWithFunction:importNop];
        [thing setArgRange:1 toMaximum:1];
        [self registerOperation:thing withName:@"import" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:labelNop];
        [thing setArgRange:1 toMaximum:1];
        [self registerOperation:thing withName:@"label" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:utiliseNop];
        [thing setArgRange:1 toMaximum:3];
        [self registerOperation:thing withName:@"utilising" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:endBlock withTargetGetter:getStackFrame andSelectorGetter:nullSelector];
        [thing setMinArgs:1];
        [self registerOperation:thing withName:@"end" withPrefix:@""];
        
        thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASFunction class], @selector(returnFunction:)) withTargetGetter:SIMASCLASSMETHODNAME(SIMASFunction) andSelectorGetter:nullSelector];
        [thing setMaxArgs:3];
        [self registerOperation:thing withName:@"ret" withPrefix:@""];
        
        thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASFunction class], @selector(jump:)) withTargetGetter:SIMASCLASSMETHODNAME(SIMASFunction) andSelectorGetter:nullSelector];
        [thing setMinArgs:1];
        [self registerOperation:thing withName:@"call" withPrefix:@""];
        
        thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASStruct class], @selector(spawn:)) withTarget:[SIMASStruct class] andSelector:@selector(spawn:)];
        [thing setArgRange:2 toMaximum:2];
        [self registerOperation:thing withName:@"new" withPrefix:@""];
        
        [self registerBlock:[SIMASBlockGeneric class]];
        [self registerBlock:[SIMASFunction class]];
        [self registerBlock:[SIMASStruct class]];
        
        [pool release];
        [self setOutputter:self forMethod:@selector(stdoutPrint:)];
        [self setErrorOutputter:self forMethod:@selector(errPrint:)];
        [self setInputter:self forMethod:@selector(stdinput)];
        self->pauseLock = [NSLock new];
        return self;
    } else {
        [self release];
        return [[[NSThread currentThread] threadDictionary] objectForKey:@"runtime"];
    }
}

+ (SIMASRuntime*)runtime {
    SIMASRuntime* runtime = [[[NSThread currentThread] threadDictionary] objectForKey:@"runtime"];
    if (!runtime) runtime = [self new];
    return runtime;
}

+ (SIMASProgram*)currentProgram {
    return [self runtime]->currentProgram;
}

+ (NSString*)userInput {
    fflush(stdout);
    return [[self runtime]->inputter performSelector:[self runtime]->inputSelector];
}

+ (id)throwException:(NSString*)exception withReason:(NSString*)reason {
    SIMASRuntime *theRuntime = [SIMASRuntime runtime];
    SIMASProgram *program = [SIMASRuntime currentProgram];
    theRuntime->exceptionOccurred = YES;
    NSArray* instructions = program ? program->instructions : nil;
    SIMASInstruction *theInstruction = nil;
    if (program && [instructions count] > program->programCounter) theInstruction = [instructions objectAtIndex:program->programCounter];
    puts("");
    [[self runtime] printError:[NSString stringWithFormat:@"A %@ exception occurred: %@", exception, reason]];
    if (theInstruction) {
        [[self runtime] printError:[NSString stringWithFormat:@"Faulty code: %@", [theInstruction stringValue]]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"InstructionFailed" object:[SIMASRuntime runtime] userInfo:[NSDictionary dictionaryWithObject:theInstruction forKey:@"instruction"]];
    }
    return nil;
}
+ (id)throwException:(NSString*)exception withReason:(NSString*)reason withInstruction:(SIMASInstruction*)instruction {
    SIMASRuntime *theRuntime = [SIMASRuntime runtime];
    theRuntime->exceptionOccurred = YES;
    [[self runtime] printError:[NSString stringWithFormat:@"A %@ exception occurred: %@\nFaulty code: %@", exception, reason, [instruction stringValue]]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"InstructionFailed" object:[SIMASRuntime runtime] userInfo:[NSDictionary dictionaryWithObject:instruction forKey:@"instruction"]];
    return nil;
}
+ (id)throwException:(NSString *)exception withReason:(NSString *)reason withSnideRemark:(NSString*)remark {
    [self throwException:exception withReason:reason];
    [[self runtime] printError:[NSString stringWithFormat:@"The person who wrote the code that triggered this exception to save you from your own stupidity would also like to say: %@.", remark]];
    return nil;
}
+ (id)throwException:(SIMASException*)exception {
    if (!exception) return nil;
    if (!exception->remark && !exception->instruction) [self throwException:exception->exception withReason:exception->reason];
    else if (exception->remark) [self throwException:exception->exception withReason:exception->reason withSnideRemark:exception->remark];
    else [self throwException:exception->exception withReason:exception->reason withInstruction:exception->instruction];
    return nil;
}
+ (SIMASException*)validateName:(NSString*)name {
    if ([name characterAtIndex:0] == '$') return [SIMASException makeWithException:@"IllegalName" andReason:@"Names starting with '$' are reserved by the SIMAS runtime."];
    if ([[SIMASRuntime runtime]->registeredTypes objectForKey:[name lowercaseString]]) return [SIMASException makeWithException:@"IllegalName" andReason:@"Names cannot be the same as a type."];
    if ([[name lowercaseString] isEqualToString:@"true"] || [[name lowercaseString] isEqualToString:@"false"]) return [SIMASException makeWithException:@"IllegalName" andReason:@"Names cannot be \"true\" or \"false\"." withRemark:@"Why on god's green earth does this have to be a rule? 'Cause fragile parsing rules :)"];
    if ([[name lowercaseString] isEqualToString:@"in"]) return [SIMASRuntime throwException:@"IllegalName" withReason:@"The \"in\" name is reserved by SIMAS for input."];
    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[name characterAtIndex:0]]) return [SIMASException makeWithException:@"IllegalName" andReason:@"Names may not start with a number."];
    if (([name rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]]).location != NSNotFound) return [SIMASException makeWithException:@"IllegalName" andReason:@"Names must consist of only alphanumeric characters."];
    return nil;
}
- (void)quitProgram {
    [self->pauseLock lock];
    self->exceptionOccurred = YES; // shit way of doing it, but this flag does indeed kill the app so
    [self->pauseLock unlock];
}
- (void)loadLibrary:(NSBundle *)libraryBundle withPrefix:(NSString*)prefix {
    if ([[libraryBundle principalClass] conformsToProtocol:@protocol(SIMASLibrary)]) [libraryBundle load];
    else return;
    [self registerLibrary:[libraryBundle principalClass] withPrefix:prefix];
}
- (void)registerLibrary:(Class)libraryClass withPrefix:(NSString*)prefix {
    if (![libraryClass conformsToProtocol:@protocol(SIMASLibrary)]) return;
    if ([registeredClasses objectForKey:libraryClass]) return;
    [libraryClass registerToSIMAS:prefix];
    [registeredClasses setObject:prefix forKey:(id<NSCopying>)libraryClass];
}
- (void)registerOperation:(SIMASOperation*)operation withName:(NSString*)name withPrefix:(NSString*)prefix {
    prefix = [prefix lowercaseString];
    name = [name lowercaseString];
    NSMutableDictionary *dict = [registeredOperations objectForKey:prefix];
    if (!name || !prefix) return;
    if (!dict) [registeredOperations setObject:(dict = [[NSMutableDictionary new] autorelease]) forKey:prefix];
    if ([dict objectForKey:name]) return;
    [dict setObject:operation forKey:name];
    [operationSet addObject:operation];
}
- (void)registerType:(Class)type withName:(NSString*)name {
    if (!name) return;
    name = [name lowercaseString];
    if ([name isEqualToString:@"in"]) [SIMASRuntime throwException:@"ReservedNameException" withReason:@"Type name 'in' is reserved."];
    else if (![registeredTypes objectForKey:name]) {
        [registeredTypes setObject:type forKey:name];
        SIMASOperation *thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASData class], @selector(spawn:)) withTarget:type andSelector:@selector(spawn:)];
        [thing setArgRange:1 toMaximum:1];
        [self registerOperation:thing withName:name withPrefix:@""];
        [typeSet addObject:thing];
    }
}
- (void)registerBlock:(Class)block {
    NSString *ident = [block performSelector:@selector(identifier)];
    if ([registeredBlocks objectForKey:ident]) return;
    [registeredBlocks setObject:block forKey:ident];
    SIMASOperation *thing = [SIMASOperation makeWithFunction:SIMASGETINSTANCEFUNCTION(block, @selector(doThings:)) withTargetGetter:getBlock andSelectorGetter:nullSelector];
    [thing setArgRange:((int(*)(void))[block methodForSelector:@selector(argumentMin)])() toMaximum:((int(*)(void))[block methodForSelector:@selector(argumentMax)])()]; // UGLY
    SIMASArgumentClassifier *classifiers = ((SIMASArgumentClassifier*(*)(void))[block methodForSelector:@selector(argClassifiers)])();
    if (classifiers) [thing setArgClassifiers:classifiers];
    [self registerOperation:thing withName:ident withPrefix:@""]; // added to the global namespace but eh it's fine
}
- (void)executeInstructions:(NSArray*)instructions {
    for (int i = 0, count = (int)[instructions count]; i < count; i++) {
        [[instructions objectAtIndex:i] execute];
        if (exceptionOccurred) break;
    }
}

- (void)runFromString:(NSString*)string {
    appPool = [NSAutoreleasePool new];
    currentProgram = [SIMASProgram loadFromString:string];
    if (exceptionOccurred) goto cleanup;
    [SIMASInstruction preprocessImports:currentProgram->instructions];
    currentProgram->baseBlock = [[SIMASBlock processBlocksForRange:NSMakeRange(0, [currentProgram->instructions count]) inInstructions:currentProgram->instructions exception:nil] retain];
    if (exceptionOccurred) goto cleanup;
    [currentProgram->stack addObject:currentProgram->baseBlock];
    [currentProgram->baseBlock preprocessLabels:currentProgram->instructions];
    if (exceptionOccurred) goto cleanup;
    for (currentProgram->programCounter = 0; currentProgram->programCounter < [currentProgram->instructions count]; currentProgram->programCounter++) {
        if ([self debugger]) { // keeps it fast as fuck on the "shit we don't need to debug" path :)
            BOOL paused, stepped = NO, excepted = [self isExcepted]; // i reallyyyy don't like the amount of locks we're using, but oh well, it'll keep the thread sanitiser happy, even if these locks are honest to god kinda pointless and just take cpu cycles
            [pauseLock lock];
            paused = self->isPaused;
            [pauseLock unlock];
            while (paused && !stepped && !excepted) {
                [NSThread sleepForTimeInterval:0.05];
                [pauseLock lock];
                paused = self->isPaused;
                stepped = self->stepped;
                excepted = self->exceptionOccurred;
                [pauseLock unlock];
            }
            if (stepped) {
                [pauseLock lock];
                self->stepped = NO;
                [pauseLock unlock];
            }
            if (excepted) break; // is fine since an exception isn't really gonna be recovered from
        }
        [[currentProgram->instructions objectAtIndex:currentProgram->programCounter] execute];
        if (exceptionOccurred) break;
    }
    cleanup:
        [appPool release];
        currentProgram = nil;
        [self->pauseLock lock];
        exceptionOccurred = NO;
        [self->pauseLock unlock];
    [self->ending performSelector:self->endingSelector];
}

- (BOOL)isExcepted {
    BOOL excepted = NO;
    [self->pauseLock lock];
    excepted = self->exceptionOccurred;
    [self->pauseLock unlock];
    return excepted;
}

- (void)setOutputter:(id)theOutputter forMethod:(SEL)method {
    self->outputter = theOutputter;
    self->outputSelector = method;
}

- (void)setErrorOutputter:(id)theOutputter forMethod:(SEL)method {
    self->errorer = theOutputter;
    self->errorSelector = method;
}

- (void)print:(NSString*)string {
    if (pthread_main_np()) [self->outputter performSelector:self->outputSelector withObject:string];
    else [self->outputter performSelectorOnMainThread:self->outputSelector withObject:string waitUntilDone:YES];
}

- (void)printError:(NSString *)string {
    if (pthread_main_np()) [self->errorer performSelector:self->errorSelector withObject:string];
    else [self->errorer performSelectorOnMainThread:self->errorSelector withObject:string waitUntilDone:YES];
}

- (void)setInputter:(id)theInputter forMethod:(SEL)method {
    self->inputter = theInputter;
    self->inputSelector = method;
}

- (void)setEnding:(id)theEnding forMethod:(SEL)method {
    self->ending = theEnding;
    self->endingSelector = method;
}

// a wall of "oh shit we might be multithreaded, we gotta be defensive"
- (void)pause {
    [pauseLock lock];
    self->isPaused = YES;
    [pauseLock unlock];
}

- (void)resume {
    [pauseLock lock];
    self->isPaused = NO;
    [pauseLock unlock];
}

- (void)step {
    [pauseLock lock];
    self->stepped = YES;
    [pauseLock unlock];
}

- (id)debugger {
    id debugger = nil;
    [pauseLock lock];
    debugger = self->debugger;
    [pauseLock unlock];
    return debugger;
}

- (void)setDebugger:(id)debugger {
    [pauseLock lock];
    self->debugger = debugger;
    [pauseLock unlock];
}

- (void)dealloc {
    [self->pauseLock release];
    [self->registeredTypes release];
    [self->registeredBlocks release];
    [self->registeredClasses release];
    [self->registeredOperations release];
    [self->operationSet release];
    [self->typeSet release];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:@"runtime"];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:@"conversions"];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:@"blockBlacklists"];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:@"blockWhitelists"];
    [super dealloc];
}
@end

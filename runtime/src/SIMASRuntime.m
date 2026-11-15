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

static pthread_key_t runtimeKey;
static pthread_once_t runtimeKeyOnce = PTHREAD_ONCE_INIT;
static BOOL hasBeenInitialisedForMultithreading = NO;

SIMASFUNC(labelNop) { return; }
SIMASFUNC(importNop) { return; }
SIMASFUNC(utiliseNop) { return; }

NSString *formatEscapes(NSString* str) {
    NSMutableString *string = [[str mutableCopy] autorelease];
    NSArray *formats = [NSArray arrayWithObjects:@"\\\"", @"\"", @"\\n", @"\n", @"\\\t", @"\t", @"\\;", @";", @"\\r", @"\r", @"\\\\", @"\\", nil];
    for (int i = 0; i < [formats count]; i += 2) [string replaceOccurrencesOfString:[formats objectAtIndex:i] withString:[formats objectAtIndex:i + 1] options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    return string;
}

NSString *unformatEscapes(NSString* str) {
    NSMutableString *string = [[str mutableCopy] autorelease];
    NSArray *formats = [NSArray arrayWithObjects:@"\\\\", @"\\", @"\\\"", @"\"", @"\\n", @"\n", @"\\\t", @"\t", @"\\;", @";", @"\\r", @"\r", nil];
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
    }
    return self;
}

+ (id)blockWithLocation:(NSRange)location {
    SIMASBlock *block = [[self class] new];
    block->location = location;
    return block;
}

+ (NSString*)identifier {
    return nil;
}

+ (BOOL)canBeNested {
    return NO;
}

- (void)doThings:(NSArray *)args {
    return;
}

- (void)addVariable:(SIMASVariable *)var forName:(NSString *)name {
    [self->variables setObject:var forKey:name];
}

- (SIMASVariable*)getVar:(NSString *)name {
    return [self->variables objectForKey:name];
}

- (void)end {
    [SIMASRuntime currentProgram]->programCounter = (int)self->location.location;
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
        case SIMASArgumentTypeName: return @"type";
        case SIMASArgumentVariableName: return @"variable name";
        case SIMASArgumentLabelName: return @"label name";
        default: return @"generic constant";
    }
}
+ (NSString*)namesForClassifiers:(SIMASArgumentClassifier)classifiers {
    SIMASArgumentClassifier current = 1;
    NSMutableArray *objs = [NSMutableArray new];
    NSMutableString *str = [[NSMutableString new] autorelease];
    while (current < 256) {
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
        if (classification & SIMASArgumentStrictMatch && !([arg classification] & [SIMASArgument standardClassification:classification])) [SIMASRuntime throwException:@"BadArgument" withReason:[NSString stringWithFormat:@"At index %d, received argument of %@, expected argument of %@", i, [SIMASArgument nameForClassifier:[arg classification]], [SIMASArgument namesForClassifiers:[SIMASArgument standardClassification:classification]]] withSnideRemark:@"Perhaps read the documentation next time?"];
    }
    newInstruction->arguments = [args copy];
    [args release];
    return newInstruction;
}

- (BOOL)isFunction:(SIMASFUNCTYPE)function {
    return self->operation->functionPointer == function;
}

- (void)execute {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    self->operation->functionPointer(self->operation->targetGetter(self->arguments), self->operation->selectorGetter(), self->arguments);
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

+ (NSMutableDictionary*)preprocessLabels:(NSMutableArray*)instructions {
    int count = (int)[instructions count];
    NSMutableDictionary* labels = [[NSMutableDictionary new] autorelease];
    for (int i = 0; i < count; i++) {
        if (((SIMASInstruction*)[instructions objectAtIndex:i])->operation->functionPointer == labelNop) {
            NSString *name = [((SIMASInstruction*)[instructions objectAtIndex:i])->arguments objectAtIndex:0];
            if ([labels objectForKey:name]) {
                [SIMASRuntime throwException:@"DuplicateLabel" withReason:[NSString stringWithFormat:@"Label '%@' is already defined.", name] withInstruction:[instructions objectAtIndex:i]];
                return nil;
            }
            [labels setObject:[NSNumber numberWithInt:i] forKey:name];
        }
    }
    return labels;
}

+ (NSMutableArray*)parseInstructionsFromString:(NSString*)string {
    NSMutableArray *instructionStrings = [NSMutableArray new];
    NSMutableString *buffer = [string mutableCopy];
    while ([string length]) { // ah shit this ends up being essentially while true XD it works tho so fuck it we ball
        NSRange rangeOfInstruction = [buffer rangeOfString:@";"];
        if (rangeOfInstruction.location == NSNotFound) break;
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSMutableString *instruction = [[NSMutableString new] autorelease];
        while (rangeOfInstruction.location > 0 && [buffer characterAtIndex:(rangeOfInstruction.location - 1)] == '\\') {
            rangeOfInstruction.length = rangeOfInstruction.location + 1;
            rangeOfInstruction.location = 0;
            [instruction appendString:[buffer substringWithRange:rangeOfInstruction]];
            [buffer deleteCharactersInRange:rangeOfInstruction];
            rangeOfInstruction = [buffer rangeOfString:@";"];
        }
        rangeOfInstruction.length = rangeOfInstruction.location;
        rangeOfInstruction.location = 0;
        if ([buffer length] < rangeOfInstruction.length) { [pool release]; break; }
        [instruction appendString:[buffer substringWithRange:rangeOfInstruction]];
        if ([buffer length] >= rangeOfInstruction.length + 1) rangeOfInstruction.length += 1;
        [buffer deleteCharactersInRange:rangeOfInstruction];
        [instructionStrings addObject:instruction];
        [pool release];
    }
    [buffer release];
    
    NSMutableArray *tokens = [NSMutableArray new];
    NSAutoreleasePool *autorel = [NSAutoreleasePool new];
    while ([instructionStrings count]) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSMutableCharacterSet *characters = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *str = [[instructionStrings objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([str length] && [str characterAtIndex:0] == '@') { [instructionStrings removeObjectAtIndex:0]; [pool release]; continue; }
        NSArray *tokenised = tokeniseStringExcludingQuotes(str, characters);
        if ([tokenised count] && [[tokenised objectAtIndex:0] length])[tokens addObject:tokenised];
        [instructionStrings removeObjectAtIndex:0];
        [pool release];
    }
    [autorel release];
    [instructionStrings release];
    
    NSMutableArray *instructions = [[NSMutableArray new] autorelease];
    while ([tokens count]) {
        NSMutableArray *string = [[tokens objectAtIndex:0] mutableCopy]; // we love accidentally shadowing our own parameters, oh well, it works so /shrug
        [tokens removeObjectAtIndex:0];
        while ([string count] && [[[string objectAtIndex:0] lowercaseString] isEqualToString:@"please"]) [string removeObjectAtIndex:0];
        if (![string count]) { [string release]; continue; }
        SIMASOperation *operation;
        if ([[[string objectAtIndex:0] lowercaseString] isEqualToString:@"utilising"]) {
            if ([string count] == 3) [SIMASRuntime throwException:@"IllegalArgumentCount"
                                                       withReason:[NSString stringWithFormat:@"The provided instruction does not contain enough arguments (either 2 or 4, got 3) for instruction utilise."]
                                                  withSnideRemark:@"like... utilising it as WHAT, buddy? \"as\" and then jack shit doesn't tell me ANYTHING i need to know, after all"];
            NSString *libName = [string objectAtIndex:1];
            NSString *prefix = [string count] == 4 && [[[string objectAtIndex:2] lowercaseString] isEqualToString:@"as"] ? [string objectAtIndex:3] : @"";
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
        instruction->name = [name retain];
        instruction->prefix = [prefix retain];
        int argCount = (int)[string count];
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
        self->labels = [NSMutableDictionary new];
        self->stack = [NSMutableArray new];
        self->variables = [NSMutableDictionary new];
    }
    return self;
}

+ (SIMASProgram*)loadFromString:(NSString*)string {
    SIMASProgram *newProgram = [SIMASProgram new];
    newProgram->instructions = [[SIMASInstruction parseInstructionsFromString:string] retain];
    return [newProgram autorelease];
}

- (void)dealloc {
    [self->functions release];
    [self->instructions release];
    [self->labels release];
    [self->stack release];
    [self->variables release];
    [super dealloc];
}
@end

SIMASCLASSMETHOD(SIMASFunction)
SIMASCLASSMETHOD(SIMASStackFrame)

id getStackFrame(NSArray* args) {
    if (![[SIMASRuntime currentProgram]->stack count]) return nil;
    if (![[[SIMASRuntime currentProgram]->stack lastObject] isKindOfClass:[SIMASStackFrame class]]) return nil;
    return [[SIMASRuntime currentProgram]->stack lastObject];
}

static void allocateRuntime() {
    pthread_key_create(&runtimeKey, NULL);
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
    if (self && pthread_getspecific(runtimeKey) == NULL) {
        pthread_setspecific(runtimeKey, self);
        registeredClasses = [NSMutableDictionary new];
        registeredTypes = [NSMutableDictionary new];
        registeredOperations = [NSMutableDictionary new];
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
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
        thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASFunction class], @selector(registerFunction:)) withTargetGetter:SIMASCLASSMETHODNAME(SIMASFunction) andSelectorGetter:nullSelector];
        [thing setMinArgs:2];
        [self registerOperation:thing withName:@"fun" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:SIMASGETFUNCTION([SIMASStackFrame class], @selector(pushStackFrame:)) withTargetGetter:SIMASCLASSMETHODNAME(SIMASStackFrame) andSelectorGetter:nullSelector];
        [thing setMinArgs:1];
        [self registerOperation:thing withName:@"call" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:SIMASGETINSTANCEFUNCTION([SIMASStackFrame class], @selector(loopStackFrame:)) withTargetGetter:getStackFrame andSelectorGetter:nullSelector];
        [thing setMinArgs:1];
        [self registerOperation:thing withName:@"end" withPrefix:@""];
        thing = [SIMASOperation makeWithFunction:SIMASGETINSTANCEFUNCTION([SIMASStackFrame class], @selector(endStackFrame:)) withTargetGetter:getStackFrame andSelectorGetter:nullSelector];
        [thing setMaxArgs:3];
        [self registerOperation:thing withName:@"ret" withPrefix:@""];
        [pool release];
        [self setOutputter:self forMethod:@selector(stdoutPrint:)];
        [self setErrorOutputter:self forMethod:@selector(errPrint:)];
        [self setInputter:self forMethod:@selector(stdinput)];
        return self;
    } else {
        [self release];
        return pthread_getspecific(runtimeKey);
    }
}

+ (SIMASRuntime*)runtime {
    if (!hasBeenInitialisedForMultithreading) {
        pthread_once(&runtimeKeyOnce, allocateRuntime);
        hasBeenInitialisedForMultithreading = YES;
    }
    SIMASRuntime* runtime = pthread_getspecific(runtimeKey);
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

+ (void)throwException:(NSString*)exception withReason:(NSString*)reason {
    SIMASRuntime *theRuntime = [SIMASRuntime runtime];
    SIMASProgram *program = [SIMASRuntime currentProgram];
    theRuntime->exceptionOccurred = YES;
    NSArray* instructions = program ? program->instructions : nil;
    SIMASInstruction *theInstruction = nil;
    if (program && [instructions count] > program->programCounter) theInstruction = [instructions objectAtIndex:program->programCounter];
    puts("");
    [[self runtime] printError:[NSString stringWithFormat:@"A %@ exception occurred: %@", exception, reason]];
    if (theInstruction) [[self runtime] printError:[NSString stringWithFormat:@"Faulty code: %@", [theInstruction stringValue]]];
}
+ (void)throwException:(NSString*)exception withReason:(NSString*)reason withInstruction:(SIMASInstruction*)instruction {
    SIMASRuntime *theRuntime = [SIMASRuntime runtime];
    theRuntime->exceptionOccurred = YES;
    [[self runtime] printError:[NSString stringWithFormat:@"A %@ exception occurred: %@\nFaulty code: %@", exception, reason, [instruction stringValue]]];
}
+ (void)throwException:(NSString *)exception withReason:(NSString *)reason withSnideRemark:(NSString*)remark {
    [self throwException:exception withReason:reason];
    [[self runtime] printError:[NSString stringWithFormat:@"The person who wrote the code that triggered this exception to save you from your own stupidity would also like to say: %@.", remark]];
}
- (void)quitProgram {
    self->exceptionOccurred = YES; // shit way of doing it, but this flag does indeed kill the app so
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
}
- (void)registerType:(Class)type withName:(NSString*)name {
    if (!name) return;
    name = [name lowercaseString];
    if ([name isEqualToString:@"in"]) [SIMASRuntime throwException:@"ReservedNameException" withReason:@"Type name 'in' is reserved."];
    else if (![registeredTypes objectForKey:name]) [registeredTypes setObject:type forKey:name];
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
    currentProgram->labels = [[SIMASInstruction preprocessLabels:currentProgram->instructions] retain];
    if (exceptionOccurred) goto cleanup;
    for (currentProgram->programCounter = 0; currentProgram->programCounter < [currentProgram->instructions count]; currentProgram->programCounter++) {
        [[currentProgram->instructions objectAtIndex:currentProgram->programCounter] execute];
        if (exceptionOccurred) break;
    }
    cleanup:
        [appPool release];
        currentProgram = nil;
        exceptionOccurred = NO;
    [self->ending performSelector:self->endingSelector];
}

- (BOOL)isExcepted { return exceptionOccurred; }

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

-(void)setEnding:(id)theEnding forMethod:(SEL)method {
    self->ending = theEnding;
    self->endingSelector = method;
}

@end

//
//  SIMASRuntime.h
//  objectivismas
//
//  Created by Xander Gomez on 9/6/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  come on now!
//  let's all get on down
//  do-si-do now!
//  we gon' have a good ol' round
//  don't be scared
//  ‘cause there ain't nothin' to worry 'bout
//  let your hair down
//  and square dance with me
//  come on now!
//  let's all get on down
//  do-si-do now!
//  we gon' have a good ol' round
//  don't be scared
//  ‘cause there ain't nothin' to worry 'bout
//  let your hair down
//  and square dance with me
//
//  eminem - square dance
//  don't be scared of this code 'cause there ain't nothin' to worry 'bout
//  just let your hair down
//  and square dance with me (and the devil, who presumably lies within this code)

#import <Foundation/Foundation.h>
#import "SIMASVariable.h"

#define SIMASFUNC(name) void name(id self, SEL _cmd, NSArray* args)
#define SIMASFUNCTYPE void (*)(id, SEL, NSArray*)
#define SIMASSELECTORMETHOD(selector, sel) SEL _simas_selector_get_##selector() { return sel; } // sel is the @selector, selector is the name (like add, @selector(add:))
#define SIMASSELECTORMETHODNAME(selector) _simas_selector_get_##selector // must be paired with one of the above declared
#define SIMASCLASSMETHOD(theClass) id _simas_class_get_##theClass(NSArray *arr) { return [theClass class]; }
#define SIMASCLASSMETHODNAME(theClass) _simas_class_get_##theClass // must be paired with one of the above declared
#define SIMASGETFUNCTION(object, selector) (SIMASFUNCTYPE)[object methodForSelector:selector]
#define SIMASGETINSTANCEFUNCTION(object, selector) (SIMASFUNCTYPE)[object instanceMethodForSelector:selector]

#define SIMASGETVARIABLEWITHARGUMENT(argument) [SIMASVariable findVariable:[[args objectAtIndex:argument] string]] // convenience macro
#define SIMASGETTYPEWITHARGUMENT(argument) [[SIMASRuntime runtime]->registeredTypes objectForKey:[[[args objectAtIndex:argument] string] lowercaseString]]

@class SIMASRuntime;

extern pthread_key_t conversionKey;

NSString *formatEscapes(NSString*);
NSString *unformatEscapes(NSString*);
NSArray *tokeniseStringExcludingQuotes(NSString*, NSCharacterSet*);

typedef NS_ENUM(long long, SIMASArgumentClassifier) {
    SIMASArgumentNumber = 1,
    SIMASArgumentBoolean = 2,
    SIMASArgumentString = 4,
    SIMASArgumentTypeName = 8, // the best thing now is i don't have to validate if a type exists since it's done at parse time
    SIMASArgumentVariableName = 16,
    SIMASArgumentInput = 32,
    SIMASArgumentGenericConstant = 64,
    SIMASArgumentThing = 128,
    SIMASArgumentUseAsFallback = 256, // tells the parser to autoeval, but use this as the fallback
    SIMASArgumentUseGeneric = 512, // tells the parser to autoeval, and use the default generic
    SIMASArgumentUseThis = 1024, // tells the parser to use EXACTLY this
    SIMASArgumentStrictMatch = 2048
};

@protocol SIMASLibrary <NSObject>
+ (void)registerToSIMAS:(NSString*)prefix;
@end

@interface SIMASOperation : NSObject {
@public
    void (*functionPointer)(id, SEL, NSArray*); // used so you can either do a standard C func OR pass in an objc method, if using the two other function pointers
    id (*targetGetter)(NSArray*); // optional
    SEL (*selectorGetter)(void); // optional, but reccommended if using targetGetter
    int minimumArguments;
    int maximumArguments;
    SIMASArgumentClassifier *classifications;
}
+ (SIMASOperation*)makeWithFunction:(void (*)(id, SEL, NSArray*))func;
+ (SIMASOperation*)makeWithFunction:(void (*)(id, SEL, NSArray*))func withTargetGetter:(id (*)(NSArray*))target andSelectorGetter:(SEL (*)(void))selector;
- (void)setMaxArgs:(int)maximum;
- (void)setMinArgs:(int)minimum;
- (void)setArgRange:(int)minimum toMaximum:(int)maximum;
- (void)setArgClassifiers:(SIMASArgumentClassifier*)classifications; // give a malloc'd or stack alloc'd. size must match maxArgs
@end

@interface SIMASArgument : NSString { // a parse-time way of telling a function what is here
    NSString *argument;
    SIMASArgumentClassifier classifier;
}
+ (id)argumentForString:(NSString*)str; // auto-classifies
+ (id)argumentForString:(NSString*)str fallback:(SIMASArgumentClassifier)fallback; // what to fall back to, in case it's not a recognised one
+ (id)argumentForString:(NSString*)str forOperation:(SIMASOperation*)op forIndex:(int)index;
+ (SIMASArgumentClassifier)standardClassification:(SIMASArgumentClassifier)src;
+ (NSString*)nameForClassifier:(SIMASArgumentClassifier)classifier;
+ (NSString*)namesForClassifiers:(SIMASArgumentClassifier)classifiers;
- (NSString*)string;
- (SIMASArgumentClassifier)classification;
- (SIMASData*)createData;
@end

@interface SIMASInstruction : NSObject {
@public
    SIMASOperation *operation;
    NSArray *arguments;
    NSString *name;
    NSString *prefix;
    NSRange rangeOfInstruction;
}
+ (id)instructionFromOperation:(SIMASOperation*)op;
+ (id)instructionFromOperation:(SIMASOperation*)op withArguments:(NSArray*)arguments;
+ (NSMutableArray*)parseInstructionsFromString:(NSString*)string;
- (BOOL)isFunction:(SIMASFUNCTYPE)function;
- (NSString*)stringValue;
- (void)execute;
@end

@interface SIMASException : NSObject { // a struct-like object. so you can save it across threads n shit
@public
    NSString *exception;
    NSString *reason;
    NSString *remark;
    SIMASInstruction *instruction;
}
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason;
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason withRemark:(NSString*)remark;
+ (id)makeWithException:(NSString*)exception andReason:(NSString*)reason withInstruction:(SIMASInstruction*)instruction;
@end

@interface SIMASBlock : NSObject {
    NSMutableDictionary *variables;
    NSMutableDictionary *labels;
    NSMutableDictionary *childNodes; // indexed by NSNumber
    NSRange location;
    SIMASBlock *parentNode; // ouuuuh SHIT is this a tree!?
}

+ (SIMASBlock*)processBlocksForRange:(NSRange)range inInstructions:(NSArray *)instructions exception:(SIMASException**)ex; // supply nil to the third arg
+ (id)blockWithLocation:(NSRange)location;
+ (NSString*)identifier; // fun
+ (int)argumentMin;
+ (int)argumentMax;
+ (SIMASArgumentClassifier*)argClassifiers; // override with static const array of things
+ (BOOL)canBeNested;
- (NSNumber*)programCounterForLabel:(NSString*)label;
- (void)enter;
- (void)preprocessLabels:(NSMutableArray*)instructions;
- (void)reg:(NSArray*)args;
- (void)addNode:(SIMASBlock*)node;
- (SIMASBlock*)findNode:(int)pc;
- (SIMASBlock*)parent;
- (void)doThings:(NSArray*)args;
- (void)addVariable:(SIMASVariable*)var forName:(NSString*)name;
- (SIMASVariable*)getVar:(NSString*)name;
- (void)deleteVariable:(NSString*)name;
- (void)end;
- (void)clearItems;
- (void)cleanUp; // called to clean up after execution of a block OR when a block is jumped out of
@end

@interface SIMASBlockGeneric : SIMASBlock
@end

@interface SIMASProgram : NSObject {
@public
    NSMutableArray *instructions;
    NSMutableArray *stack;
    NSMutableDictionary *functions;
    SIMASBlock *baseBlock;
    int programCounter;
}
@end

@interface SIMASRuntime : NSObject {
    NSAutoreleasePool *appPool;
    SIMASProgram *currentProgram;
    BOOL exceptionOccurred; // should this be like this? probably not. is it a good cheap way to check though? yeeeeeee
    id outputter;
    id errorer;
    id inputter;
    id ending;
    SEL outputSelector;
    SEL errorSelector;
    SEL inputSelector;
    SEL endingSelector;
    BOOL isPaused;
    BOOL stepped;
    NSLock *pauseLock;
@public
    NSMutableDictionary *registeredClasses;
    NSMutableDictionary *registeredOperations;
    NSMutableDictionary *registeredTypes; // types like num, bool, str are the keys, the classes are the values
    NSMutableDictionary *registeredBlocks;
}

+ (SIMASRuntime*)runtime;
+ (SIMASProgram*)currentProgram;
+ (NSString*)userInput;
+ (id)throwException:(NSString*)exception withReason:(NSString*)reason; // nil so you can return it as nil itself
+ (id)throwException:(NSString*)exception withReason:(NSString*)reason withSnideRemark:(NSString*)remark;
+ (id)throwException:(NSString*)exception withReason:(NSString*)reason withInstruction:(SIMASInstruction*)instruction;
+ (id)throwException:(SIMASException*)exception;
// there must be a class method named "registerToSIMAS:". this removes itself on program end. prefix may not be nil, but may be "" if you want it to be root-level (no prefix).
// the prefix is provided for you in the "utilising" (utilising [bundle] as [prefix]).
// you can, theoretically, ignore the passed prefix, but it's reccommended to register your things with the user prefix (unless none is provided, then do whatever)
- (void)loadLibrary:(NSBundle*)libraryBundle withPrefix:(NSString*)prefix; // loads a library from a bundle, for the "utilising" thing
- (void)registerLibrary:(Class)libraryClass withPrefix:(NSString*)prefix;
- (void)registerOperation:(SIMASOperation*)operation withName:(NSString*)name withPrefix:(NSString*)prefix;
- (void)registerType:(Class)type withName:(NSString*)name;
- (void)registerBlock:(Class)block;
- (void)executeInstructions:(NSArray*)instructions; // runs instructions DURING the program, but does not insert itself into the program. some functions may work wrongly/improperly, as these are not preprocessed by default
- (void)runFromString:(NSString*)string; // does all the setup for you
- (void)setOutputter:(id)theOutputter forMethod:(SEL)method;
- (void)setErrorOutputter:(id)theOutputter forMethod:(SEL)method;
- (void)setInputter:(id)theInputter forMethod:(SEL)method;
- (void)setEnding:(id)theEnding forMethod:(SEL)method;
- (void)print:(NSString*)string;
- (void)printError:(NSString*)string;
- (void)quitProgram;
- (void)pause;
- (void)resume;
- (void)step;

- (BOOL)isExcepted;
@end

static inline SEL nullSelector() { return NULL; }
static inline id nullTarget(NSArray* arr) { return nil; }

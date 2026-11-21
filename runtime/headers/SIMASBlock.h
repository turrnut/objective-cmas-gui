//
//  SIMASBlock.h
//  simas_runtime
//
//  Created by Xander Gomez on 11/20/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SIMASRuntime.h"

@interface SIMASBlock : NSObject {
    NSMutableDictionary *variables;
    NSMutableDictionary *labels;
    NSMutableDictionary *childNodes; // indexed by NSNumber
    NSMutableDictionary *instantiatedStructs;
    NSRange location;
    SIMASBlock *parentNode; // ouuuuh SHIT is this a tree!?
    BOOL isClone;
}

+ (SIMASBlock*)processBlocksForRange:(NSRange)range inInstructions:(NSArray *)instructions exception:(SIMASException**)ex; // supply nil to the third arg
+ (id)blockWithLocation:(NSRange)location;
+ (NSString*)identifier; // fun
+ (int)argumentMin;
+ (int)argumentMax;
+ (SIMASArgumentClassifier*)argClassifiers; // override with static const array of things
+ (BOOL)canBeNested;
// please note that if you're whitelisting/blacklisting by getting an object, it must go through (the runtime)->operations->object for key: a prefix->object for key: the operation you want to put on a list
+ (BOOL)usesWhitelist; // NO by default. if yes, it will ONLY allow instructions from your whitelist. if no, it will allow all instructions (except those in the blacklist, if enabled)
+ (BOOL)usesBlacklist; // YES by default, used to disable instructions like ret from running in non-function instructions.
+ (NSMutableSet*)whitelist; // list of instructions ALLOWED to run in this block
+ (NSMutableSet*)blacklist; // list of instructions DISallowed from running in this block
+ (void)initWhitelistData; // this is where you'd set your WHITELIST's data. called on allocation of whitelist
+ (void)initBlacklistData; // this is where you'd set your BLACKLIST's data. called on allocation of blacklist
- (NSNumber*)programCounterForLabel:(NSString*)label;
- (void)enter;
- (void)preprocessLabels:(NSMutableArray*)instructions;
- (void)reg:(NSArray*)args withException:(SIMASException**)ex;
- (void)addNode:(SIMASBlock*)node;
- (SIMASBlock*)findNode:(int)pc;
- (SIMASBlock*)parent;
- (void)doThings:(NSArray*)args;
- (void)addVariable:(SIMASVariable*)var forName:(NSString*)name;
- (SIMASVariable*)getVar:(NSString*)name;
- (id)getStruct:(NSString*)name;
- (void)deleteVariable:(NSString*)name;
- (void)end;
- (void)clearItems;
- (void)cleanUp; // called to clean up after execution of a block OR when a block is jumped out of
- (SIMASBlock*)clone; // this returns a clone (strongly held, but autodeleted with cleanup)
- (SIMASBlock*)recursivelyClone;
- (void)removeFromStack;
@end

@interface SIMASBlockGeneric : SIMASBlock
@end

@interface SIMASStruct : SIMASBlock {
    NSArray *instructions;
    NSString *name;
}
+ (void)spawn:(NSArray*)args;
+ (SIMASStruct*)findStruct:(NSString*)name;
@end

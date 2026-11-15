//
//  Document.m
//  Objective-CMAS GUI
//
//  Created by Xander Gomez on 11/13/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//

#import "Document.h"
#import "SIMASRuntime.h"
#import "SIMASStandardLibrary.h"
#import "SIMASList.h"
#import <objc/runtime.h>
#import <pthread.h>

@interface Document ()

@end

@implementation Document
- (void)printOutput:(NSString*)str {
    self.output.string = [self.output.string stringByAppendingString:str];
    [self.output scrollToEndOfDocument:nil];
}

- (void)printError:(NSString*)str {
    self.errors.string = [self.errors.string stringByAppendingString:str];
    [self.output scrollToEndOfDocument:nil];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self->inputConditional lock];
    [self.input.window makeFirstResponder:self.content];
    self.input.editable = NO;
    self.input.enabled = NO;
    self.userInput = self.input.stringValue;
    [self->inputConditional signal];
    [self->inputConditional unlock];
}

- (void)wakeUpInput {
    self.userInput = nil;
    self.input.enabled = YES;
    self.input.editable = YES;
    [self.input.window makeFirstResponder:self.input];
}

- (void)lockInput {
    self.input.stringValue = @"";
    self.input.enabled = NO;
}

- (NSString*)takeUserInput {
    NSString *str = nil;
    [self->inputConditional lock];
    [self performSelectorOnMainThread:@selector(wakeUpInput) withObject:nil waitUntilDone:YES];
    while (!self.userInput) [self->inputConditional wait];
    [self->inputConditional unlock];
    str = [[self.userInput copy] autorelease];
    [self performSelectorOnMainThread:@selector(lockInput) withObject:nil waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(printOutput:) withObject:[str stringByAppendingString:@"\n"] waitUntilDone:YES];
    [self.userInput release];
    self.userInput = nil;
    return str;
}

- (void)prepareRuntime {
    self->runtime = [SIMASRuntime runtime];
    [self->runtime registerLibrary:[SIMASStandardLibrary class] withPrefix:@""];
    [self->runtime registerLibrary:[SIMASListLibrary class] withPrefix:@"List"];
    [self->runtime setOutputter:self forMethod:@selector(printOutput:)];
    [self->runtime setErrorOutputter:self forMethod:@selector(printError:)];
    [self->runtime setInputter:self forMethod:@selector(takeUserInput)];
    [self->runtime setEnding:self forMethod:@selector(stopProgram)];
relapse:
    [self->runtimeConditional lock];
    while (!self->isRunning) [self->runtimeConditional wait];
    if (self->fileContents) {
        [[self->runner retain] invoke];
        [self->runner release];
        self->runner = nil;
    }
    else [self stopProgram];
    [self->runtimeConditional unlock];
    goto relapse; // prevent the stack from building over time by immediately jumping back and waiting, rather than reinvoking after program exit. essentially a spinlock but tastier
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self->inputConditional = [NSCondition new];
        self->runtimeConditional = [NSCondition new];
    }
    return self;
}

+ (BOOL)autosavesInPlace {
    return YES;
}

- (NSUndoManager*)undoManagerForTextView:(NSTextView *)view {
    return self.undoManager;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    if (self->fileContents) self.content.string = self->fileContents;
    self.content.font = [NSFont fontWithName:@"Monaco" size:12.0f];
    self.content.textContainer.widthTracksTextView = NO;
    self.content.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    [NSThread detachNewThreadSelector:@selector(prepareRuntime) toTarget:self withObject:nil];
}

- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error if you return nil.
    // Alternatively, you could remove this method and override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    if (self->fileContents) [self->fileContents release];
    self->fileContents = [[self.content string] copy];
    return [self->fileContents dataUsingEncoding:NSUTF8StringEncoding];
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error if you return NO.
    // Alternatively, you could remove this method and override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you do, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    if (self->fileContents) [self->fileContents release];
    self->fileContents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return YES;
}

- (void)startProgram {
    [self->runtimeConditional lock];
    self.output.string = @"";
    self.errors.string = @"";
    self.input.stringValue = @"";
    self.toggleSwitch.title = @"stop that shit bruh";
    self->runner = [NSInvocation invocationWithMethodSignature:[self->runtime methodSignatureForSelector:@selector(runFromString:)]];
    [self->runner setTarget:self->runtime];
    [self->runner setSelector:@selector(runFromString:)];
    [self->runner setArgument:&self->fileContents atIndex:2];
    [self->runner retainArguments];
    self->isRunning = YES;
    [self->runtimeConditional signal];
    [self->runtimeConditional unlock];
}

- (void)stopProgram {
    [self performSelectorOnMainThread:@selector(controlTextDidEndEditing:) withObject:nil waitUntilDone:YES];
    [self.toggleSwitch performSelectorOnMainThread:@selector(setTitle:) withObject:@"run that shit burh" waitUntilDone:NO];
    self->isRunning = NO;
}

- (IBAction)runTheProgram:(id)sender {
    if (self->isRunning) [self->runtime quitProgram]; // tis not a threading violation since the code that actually checks the raised flag is still running on the OTHER thread.
    else [self startProgram];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
    if (self->isRunning) [self->runtime quitProgram];
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self->runtime release];
    [self->fileContents release];
    [self->runner release];
    [self->_input release];
    [self->_output release];
    [self->_errors release];
    [self->_content release];
    [self->_toggleSwitch release];
    [super dealloc];
}

@end

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
    self->userHasInputted = YES;
    [self->inputConditional signal];
    [self->inputConditional unlock];
}

- (void)wakeUpInput {
    self.input.enabled = YES;
    self.input.editable = YES;
    [self.input.window makeFirstResponder:self.input];
    self.input.stringValue = @"";
    self->userHasInputted = NO;
}

- (void)lockInput {
    self.input.stringValue = @"";
    self.input.enabled = NO;
}

- (NSString*)doSomeJank {
    static NSString *theString = nil;
    theString = nil;
    if (pthread_main_np()) theString = self.input.stringValue;
    else [self performSelectorOnMainThread:_cmd withObject:nil waitUntilDone:YES];
    return theString;
}

- (NSString*)takeUserInput {
    NSString *str = nil;
    [self->inputConditional lock];
    [self performSelectorOnMainThread:@selector(wakeUpInput) withObject:nil waitUntilDone:YES];
    while (!self->userHasInputted) [self->inputConditional wait];
    self->userHasInputted = NO;
    [self->inputConditional unlock];
    str = [self doSomeJank];
    [self performSelectorOnMainThread:@selector(lockInput) withObject:nil waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(printOutput:) withObject:[str stringByAppendingString:@"\n"] waitUntilDone:YES];
    return str;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self->inputConditional = [NSCondition new];
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

- (void)programStarter {
    self.output.string = @"";
    self.errors.string = @"";
    self.input.stringValue = @"";
    [self saveDocument:self];
    self.toggleSwitch.title = @"stop that shit bruh";
}

- (void)startProgram {
    [self performSelectorOnMainThread:@selector(programStarter) withObject:nil waitUntilDone:YES];
    self->runtime = [SIMASRuntime runtime];
    [self->runtime registerLibrary:[SIMASStandardLibrary class] withPrefix:@""];
    [self->runtime registerLibrary:[SIMASListLibrary class] withPrefix:@"List"];
    [self->runtime setOutputter:self forMethod:@selector(printOutput:)];
    [self->runtime setErrorOutputter:self forMethod:@selector(printError:)];
    [self->runtime setInputter:self forMethod:@selector(takeUserInput)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopProgram:) name:@"ProgramHasEnded" object:self->runtime];
    [self->runtime runFromString:self->fileContents];
}

- (void)stopProgram:(NSNotification*)notif {
    [self performSelectorOnMainThread:@selector(controlTextDidEndEditing:) withObject:nil waitUntilDone:YES];
    [self.toggleSwitch performSelectorOnMainThread:@selector(setTitle:) withObject:@"run that shit burh" waitUntilDone:NO];
    [self->runtime release];
    self->runtime = nil;
}

- (IBAction)runTheProgram:(id)sender {
    if (self->runtime) [self->runtime quitProgram];
    else [NSThread detachNewThreadSelector:@selector(startProgram) toTarget:self withObject:nil];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
    if (self->runtime) [self->runtime quitProgram];
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self->fileContents release];
    [self->_input release];
    [self->_output release];
    [self->_errors release];
    [self->_content release];
    [self->_toggleSwitch release];
    [super dealloc];
}

@end

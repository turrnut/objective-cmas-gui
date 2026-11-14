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

@interface Document ()

@end

@implementation Document
- (void)printOutput:(NSString*)str {
    self.output.string = [self.output.string stringByAppendingString:str];
}

- (void)printError:(NSString*)str {
    self.errors.string = [self.errors.string stringByAppendingString:str];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [SIMASRuntime nullifyRuntime];
        self->runtime = [SIMASRuntime runtime];
        [self->runtime registerLibrary:[SIMASStandardLibrary class] withPrefix:@""];
        [self->runtime registerLibrary:[SIMASListLibrary class] withPrefix:@"List"];
        [self->runtime setOutputter:self forMethod:@selector(printOutput:)];
        [self->runtime setErrorOutputter:self forMethod:@selector(printError:)];
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

- (IBAction)runTheProgram:(id)sender {
    static NSLock *lock = nil;
    if (!lock) lock = [NSLock new];
    self.output.string = @"";
    self.errors.string = @"";
    [self saveDocument:self];
    [lock lock];
    [self->runtime setAsRuntime];
    [NSThread detachNewThreadSelector:@selector(runFromString:) toTarget:self->runtime withObject:self->fileContents];
    [lock unlock];
}

- (void)dealloc {
    [self->fileContents release];
    [self->runtime release];
    [super dealloc];
}

@end

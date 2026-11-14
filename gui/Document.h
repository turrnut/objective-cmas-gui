//
//  Document.h
//  Objective-CMAS GUI
//
//  Created by Xander Gomez on 11/13/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SIMASRuntime.h"

@interface Document : NSDocument <NSTextViewDelegate, NSTextFieldDelegate> {
    NSString *fileContents;
    SIMASRuntime *runtime;
    
    NSCondition* inputConditional;
    BOOL userHasInputted;
    
    NSAutoreleasePool *programPool;
    BOOL runtimeIsRunning;
}

@property (nonatomic, assign) IBOutlet NSButton *toggleSwitch;
@property (nonatomic, assign) IBOutlet NSTextView *content;
@property (nonatomic, assign) IBOutlet NSTextView *errors;
@property (nonatomic, assign) IBOutlet NSTextView *output;
@property (nonatomic, assign) IBOutlet NSTextField *input;
@property (nonatomic, assign) NSLock *lock;

- (IBAction)runTheProgram:(id)sender;
@end


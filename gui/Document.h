//
//  Document.h
//  Objective-CMAS GUI
//
//  Created by Xander Gomez on 11/13/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  These segfaults make us who we are, who we are, we are
//  We're motivated by the scars that we're made of
//  These segfaults make us who we are, who we are, we are
//  We take our places in the dark
//  And turn our hearts to the stars
//
//  starset - trials

#import <Cocoa/Cocoa.h>
#import "SIMASRuntime.h"

@interface Document : NSDocument <NSTextViewDelegate, NSTextFieldDelegate, NSSplitViewDelegate> {
    NSString *fileContents;
    SIMASRuntime *runtime;
    
    NSCondition* inputConditional;
    
    NSInvocation* runner;
    NSCondition* runtimeConditional;
    BOOL isRunning;
    BOOL isPaused;
    
    NSRange highlightedRange;
}

@property (nonatomic, retain) IBOutlet NSButton *toggleSwitch;
@property (nonatomic, retain) IBOutlet NSTextView *content;
@property (nonatomic, retain) IBOutlet NSTextView *errors;
@property (nonatomic, retain) IBOutlet NSTextView *output;
@property (nonatomic, retain) IBOutlet NSTextField *input;
@property (nonatomic, retain) IBOutlet NSButton *highlightSwitch;
@property (nonatomic, assign) IBOutlet NSSplitView *mainSplitView;
@property (nonatomic, assign) IBOutlet NSSplitView *runtimeSplitView;
@property (nonatomic, assign) IBOutlet NSSplitView *debugSplitView;
@property (nonatomic, retain) IBOutlet NSTextField *programCounter;
@property (nonatomic, retain) IBOutlet NSButton *pauseButton;
@property (nonatomic, retain) IBOutlet NSButton *stepButton;
@property (nonatomic, copy) NSString* userInput;

- (IBAction)runTheProgram:(id)sender;
- (IBAction)toggleProgram:(id)sender;
- (IBAction)stepProgram:(id)sender;
- (void)stopProgram;
@end


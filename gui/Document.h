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
    
    NSInvocation* runner;
    NSCondition* runtimeConditional;
    BOOL isRunning;
}

@property (nonatomic, retain) IBOutlet NSButton *toggleSwitch;
@property (nonatomic, retain) IBOutlet NSTextView *content;
@property (nonatomic, retain) IBOutlet NSTextView *errors;
@property (nonatomic, retain) IBOutlet NSTextView *output;
@property (nonatomic, retain) IBOutlet NSTextField *input;
@property (nonatomic, copy) NSString* userInput;

- (IBAction)runTheProgram:(id)sender;
@end


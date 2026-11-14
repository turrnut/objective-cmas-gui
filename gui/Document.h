//
//  Document.h
//  Objective-CMAS GUI
//
//  Created by Xander Gomez on 11/13/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SIMASRuntime.h"

@interface Document : NSDocument <NSTextViewDelegate> {
    NSString *fileContents;
    SIMASRuntime *runtime;
}

@property (nonatomic, retain) IBOutlet NSTextView *content;
@property (nonatomic, retain) IBOutlet NSTextView *errors;
@property (nonatomic, retain) IBOutlet NSTextView *output;

- (IBAction)runTheProgram:(id)sender;
@end


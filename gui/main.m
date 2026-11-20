//
//  main.m
//  Objective-CMAS GUI
//
//  Created by Xander Gomez on 11/13/26.
//  Copyright © 2026 Xander Gomez. All rights reserved.
//
//  I am the one, don't weigh a ton
//  Don't need a gun to get respect up on the street (okay)
//  Under the sun, the bastard son
//  Will pop the Glock to feed himself and family (sheesh)
//  By any means, your enemies my enemies
//  We wet them up like a canteen (damn)
//  The yellow tape surrounds the fate
//  Don't have a face so now you late, open the gates
//
//  denzel curry - ultimate
//  i really do listen to a wide array of shit huh
//  anyways if you don't recognise this song, what the fuck were you doing in 2016?
//  sincerely, the local human fetus

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    NSString* str = nil;
    NSScanner *scan = [NSScanner scannerWithString:@"this->is->a->test"];
    [scan scanUpToString:@"->" intoString:&str];
    NSLog(str);
    [scan scanUpToString:@"->" intoString:&str];
    NSLog(str);
    return NSApplicationMain(argc, argv);
}

//
//  Test.m
//  Rover
//
//  Created by Ata Namvari on 2016-01-25.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

#import "Test.h"
@import Rover;

@implementation Test

- (void)testMethod {
    [Rover setupWithApplicationToken:@"someToken"];
    [Rover startMonitoring];
    [Rover registerForNotifications];
    [Rover stopMonitoring];
    
}

@end

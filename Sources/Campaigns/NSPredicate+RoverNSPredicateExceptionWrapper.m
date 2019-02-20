//
//  NSPredicate+ExceptionWrapper.m
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-20.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NSPredicate+RoverNSPredicateExceptionWrapper.h>
#import <os/log.h>

@implementation NSPredicate (RoverNSPredicateExceptionWrapper)

- (BOOL)evaluateWithObjectSwallowingExceptions:(id)object {
    @try {
        return [self evaluateWithObject:object];
    } @catch (NSException *exception) {
        os_log(OS_LOG_DEFAULT, "Problem evaluating NSPredicate: %@", [exception debugDescription]);
        return false;
    }
}

@end

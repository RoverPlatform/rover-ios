//
//  NSPredicate+RoverNSPredicateExceptionWrapper.h
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-20.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPredicate (RoverNSPredicateExceptionWrapper)
/*! @brief Use this method from Swift to treat invalid NSPredicate errors as non-matching soft failures.  Useful for use from Swift where the Objective-C exceptions emitted by NSPredicate cannot be caught. !*/
- (BOOL)evaluateWithObjectSwallowingExceptions:(id)object;
@end

NS_ASSUME_NONNULL_END

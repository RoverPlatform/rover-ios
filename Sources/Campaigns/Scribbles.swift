//
//  Scribbles.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os
import CoreData

func relevantCampaigns(event: Event, in context: NSManagedObjectContext) -> [AutomatedCampaign] {
    
    // ultimately we have to filter by:
    // * CD queryable: for AutomatedCampaigns only
    // * CD queryable: event name & namespace
    // * CD queryable: the queryable flattened event trigger types: day of week, time of day.
    // * a non-queryable event trigger filter type, event attributes, that needs predicate evaluation: predicate from each remaining campaign against the event.
    // * a non-queryable event trigger filter type, scheduled, that needs its DateTimeComponents transformed into local time as needed.  Too complex to query on directly through Core Data.
    // * a non-queryable: campaign segmentation, that also needs predicate evaluation: predicate from each remaining campaign against DeviceSnapshot.
    
    // start by filter by event name and namespace.

    return []
}

extension Predicate {
    func nsPredicate() -> NSPredicate {
        let nsPredicate: NSPredicate

        switch self {
        case let comparisonPredicate as ComparisonPredicate:
            nsPredicate = comparisonPredicate.nsPredicate()
        case let compoundPredicate as CompoundPredicate:
            nsPredicate = compoundPredicate.nsPredicate()
        default:
            nsPredicate = NSPredicate()
        }

        return nsPredicate
    }
}

extension ComparisonPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    func nsPredicate() -> NSPredicate {
        // Left-hand-side value will be the item being tested (as given by keypath).
        // Right-hand-side value is the constant value given.
        
        let rightExpression = NSExpression(forKeyPath: self.keyPath)
        
        // The Predicate has just a single value, to be used as the RHS value.  However, for GraphQL typing reasons separate fields are needed to cover all the types, and nils are used in the unneeded fields. Exactly one should be not nil.  So we aggregate them all down into a single Any? value.
        // can't use one big expression here because the Swift compiler's type inference lags out, so aggregate the nil values in several chunks.
        let value1: Any? = self.booleanValue ?? self.booleanValues
        let value2: Any? = self.dateTimeValue ?? self.dateTimeValues
        let value3: Any? = self.numberValue ?? self.numberValues
        let value4: Any? = self.stringValue ?? self.stringValues
        let value: Any? = value1 ?? value2 ?? value3 ?? value4
        
        if value == nil {
            // this means the Predicate given from GraphQL was invalid.
            os_log("Predicate was missing an RHS value.  Cloud API should not have given us such a Predicate.", log: .campaigns, type: .error)
            return NSPredicate(value: false)
        }
        
        let leftExpression = NSExpression(
            forConstantValue: value
        )
        
        return NSComparisonPredicate(
            leftExpression: leftExpression,
            rightExpression: rightExpression,
            modifier: modifier.nsModifier,
            type: `operator`.nsOperator,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
}

extension CompoundPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    func nsPredicate() -> NSPredicate {
        let nsPredicates = self.predicates.map { predicate in
            predicate.nsPredicate()
        }
        
        return NSCompoundPredicate(type: self.booleanOperator.nsLogicalType, subpredicates: nsPredicates)
    }
}

extension ComparisonPredicateOperator {
    /// Map the Rover comparison predicate operator type into its equivalent Apple NSPredicate type.
    var nsOperator: NSComparisonPredicate.Operator {
        switch self {
        case .lessThan:
            return .lessThan
        case .lessThanOrEqualTo:
            return .lessThanOrEqualTo
        case .greaterThan:
            return .greaterThan
        case .greaterThanOrEqualTo:
            return .greaterThanOrEqualTo
        case .equalTo:
            return .equalTo
        case .notEqualTo:
            return .notEqualTo
        case .like:
            return .like
        case .beginsWith:
            return .beginsWith
        case .endsWith:
            return .endsWith
        case .in:
            return .in
        case .contains:
            return .contains
        case .between:
            return .between
        case .geoWithin:
            // TODO: uh this has to be handled separately.  An entire compound predicate needs to be constructed with multiple expressions.
            fatalError("geoWithin operator not yet implemented")
        }
    }
}

extension ComparisonPredicateModifier {
    /// Map the Rover comparison predicate modifier type into its equivalent Apple NSPredicate type.
    var nsModifier: NSComparisonPredicate.Modifier {
        switch self {
        case .all:
            return .all
        case .any:
            return .any
        case .direct:
            return .direct
        }
    }
}

extension CompoundPredicateLogicalType {
    /// Map the Rover compound predicate logical type into its equivalent Apple NSPredicate type.
    var nsLogicalType: NSCompoundPredicate.LogicalType {
        switch self {
        case .and:
            return .and
        case .or:
            return .or
        case .not:
            return .not
        }
    }
}

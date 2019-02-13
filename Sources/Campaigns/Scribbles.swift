//
//  Scribbles.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

class CampaignUpdateObserver {
    
}

struct CampaignEventPipeline {
    // stage 1:  monitor for campaign updates.  do so right from Core Data.
    
//    init() {
//        NotificationCenter.default.addObserver(self, selector: #selector(contextObjectsDidChange(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
//    }
//
//    @objc
//    func contextObjectsDidChange(_ notification: Foundation.Notification) {
//
//    }
}

struct SegmentModel {
}

protocol Segmentable {
    var segment: SegmentModel { get }
}

extension AutomatedCampaign: Segmentable {
    var segment: SegmentModel {
        fatalError("stand-in")
    }
}

extension ScheduledCampaign: Segmentable {
    var segment: SegmentModel {
        fatalError("Coming later!")
    }
}

extension Array where Element == Segmentable {
    // filter segmentables
    func filterForDevice(deviceSnapshot: DeviceSnapshot) {
        // TODO: evaluate predicates.
    }
}

extension Predicate {
    func nsPredicate(forDevice deviceSnapshot: DeviceSnapshot) -> NSPredicate {
        let nsPredicate: NSPredicate

        switch self {
        case let comparisonPredicate as ComparisonPredicate:
            nsPredicate = comparisonPredicate.nsPredicate(forDevice: deviceSnapshot)
        case let compoundPredicate as CompoundPredicate:
            nsPredicate = compoundPredicate.nsPredicate(forDevice: deviceSnapshot)
        default:
            nsPredicate = NSPredicate()
        }

        return nsPredicate
    }
}

extension ComparisonPredicate {
    func nsPredicate() -> NSPredicate {
        // Left-hand-side value will be the item being tested (as given by keypath)
        // Right-hand-side value is the constant value given
        
        let rightExpression = NSExpression(forKeyPath: self.keyPath)
        
        // can't use one big expression here because the Swift compiler lags out.
        let value1: Any? = self.booleanValue ?? self.booleanValues
        let value2: Any? = self.dateTimeValue ?? self.dateTimeValues
        let value3: Any? = self.numberValue ?? self.numberValues
        let value4: Any? = self.stringValue ?? self.stringValues
        let value: Any? = value1 ?? value2 ?? value3 ?? value4
        
        if value == nil {
            // TODO: this means the Predicate given from GraphQL was invalid?  Handling this case by matching nothing.
            os_log("feck", log: .campaigns)
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
    func nsPredicate(forDevice deviceSnapshot: DeviceSnapshot) -> NSPredicate {
        // ANDREW START HERE
    }
}

extension ComparisonPredicateOperator {
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

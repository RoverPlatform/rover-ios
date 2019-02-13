//
//  AutomatedCampaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

public final class AutomatedCampaign: Campaign {
    // TODO: fetch request accessor
    
    // fields:
    // eventName: String
    // eventNameSpace: String?
    
    // flattened trigger filters:
    // day of week:
    
    

    public private(set) var dayOfWeekFilterMonday: Bool? {
        get {
            return getOptionalBooleanForPrimitiveField(forKey: dayOfWeekFilterMondayFieldName)
        }
        set {
            setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: "dayOfWeekFilterMondayFieldName")
        }
    }
    
    
    
    // dayOfWeekFilterTuesday: BooleanValue?
    // dayOfWeekFilterWednesday: BooleanValue?
    // dayOfWeekFilterThursday: BooleanValue?
    // dayOfWeekFilterFriday: BooleanValue?
    // dayOfWeekFilterSaturday: BooleanValue?
    // dayOfWeekFilterSunday: BooleanValue?
    
    // TODO: ANDREW START HERE
    @NSManaged public var timeOfDayFilterStartTime: Int?
    // timeOfDayFilterEndTime: Int?
    
    //
    
    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
    }
    
    public private(set) var triggerSegmentPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: triggerSegmentPredicateFieldName)
        }
        set {
            setPrimitiveValue(newValue, forKey: triggerSegmentPredicateFieldName)
        }
    }

    public private(set) var eventAttributeFilterPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: eventAttributeFilterPredicateFieldName)
        }
        set {
            setPrimitiveValue(newValue, forKey: eventAttributeFilterPredicateFieldName)
        }
    }
    
    private func getPredicateForPrimitiveField(forKey key: String) -> Predicate? {
        self.willAccessValue(forKey: key)
        defer { self.didAccessValue(forKey: key) }
        guard let primitiveValue = primitiveValue(forKey: key) as? Data else {
            return nil
        }
        
        guard let predicateType = try? JSONDecoder.default.decode(PredicateType.self, from: primitiveValue) else {
            os_log("Unable to determine type of predicate stored in Core Data.", log: .persistence, type: .error)
            return nil
        }
        
        do {
            switch predicateType {
            case .comparisonPredicate:
                return try JSONDecoder.default.decode(ComparisonPredicate.self, from: primitiveValue)
            case .compoundPredicate:
                return try JSONDecoder.default.decode(CompoundPredicate.self, from: primitiveValue)
            }
        } catch {
            os_log("Unable to decode predicate stored in core data: %s", log: .persistence, type: .error, String(describing: error))
            return nil
        }
    }
    
    private func setPredicateForPrimitiveField(newValue: Predicate?, forKey key: String) {
        let key = eventAttributeFilterPredicateFieldName
        willChangeValue(forKey: key)
        defer { didChangeValue(forKey: key) }
        let primitiveValue: Data
        
        guard let newValue = newValue else {
            setPrimitiveValue(nil, forKey: key)
            return
        }
        
        do {
            switch newValue {
            case let compound as CompoundPredicate:
                primitiveValue = try JSONEncoder.default.encode(compound)
            case let comparison as ComparisonPredicate:
                primitiveValue = try JSONEncoder.default.encode(comparison)
            default:
                let context = EncodingError.Context(codingPath: [], debugDescription: "Unexpected predicate type appeared during encode.")
                throw EncodingError.invalidValue(newValue, context)
            }
        } catch {
            os_log("Unable to encode predicate for storage in core data: %@", log: .persistence, type: .error, String(describing: error))
            return
        }
        
        setPrimitiveValue(primitiveValue, forKey: key)
    }
    
    private func getOptionalBooleanForPrimitiveField(forKey key: String) -> Bool? {
        let key = timeOfDayFilterStartTimeFieldName
        self.willAccessValue(forKey: key)
        defer { self.didAccessValue(forKey: key) }
        guard let primitiveValue = primitiveValue(forKey: key) as? NSNumber else {
            return nil
        }
        return primitiveValue != 0
    }
    
    private func setOptionalBooleanForPrimitiveField(newValue: Bool?, forKey key: String) {
        let key = timeOfDayFilterStartTimeFieldName
        willChangeValue(forKey: key)
        defer { didChangeValue(forKey: key) }
        
        guard let newValue = newValue else {
            setPrimitiveValue(nil, forKey: key)
            return
        }
        setPrimitiveValue(NSNumber(booleanLiteral: newValue), forKey: key)
    }
    
    
    // TODO: screw it, turn these into an "Attributes" enum of some sort, use automatic string value to produce key strings.
    private let eventAttributeFilterPredicateFieldName = "eventAttributeFilterPredicate"
    private let triggerSegmentPredicateFieldName = "triggerSegmentPredicate"
    private let timeOfDayFilterStartTimeFieldName = "timeOfDayFilterStartTime"
    private let dayOfWeekFilterMondayFieldName = "dayOfWeekFilterMonday"
}

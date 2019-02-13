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
    
    // dayOfWeekFilterMonday: Bool?
    // dayOfWeekFilterTuesday: Bool?
    // dayOfWeekFilterWednesday: Bool?
    // dayOfWeekFilterThursday: Bool?
    // dayOfWeekFilterFriday: Bool?
    // dayOfWeekFilterSaturday: Bool?
    // dayOfWeekFilterSunday: Bool?
    
    // timeOfDayFilterStartTime: Int?
    // timeOfDayFilterEndTime: Int?
    
    //
    
    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
    }
    
    // Event Attributes filter predicate
    
    // Segment filter predicate
    
    //
    public private(set) var eventAttributeFilterPredicate: Predicate? {
        get {
            let key = eventAttributeFilterPredicateFieldName
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
        set {
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
    }
    
    private let eventAttributeFilterPredicateFieldName = "eventAttributeFilterPredicate"
}

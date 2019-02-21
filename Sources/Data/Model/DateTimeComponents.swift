//
//  DateTimeComponents.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-02-14.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

public struct DateTimeComponents: Codable {
    /// The date, formatted as yyyy-mm-dd.
    public let date: String
    
    /// Seconds since midnight.
    public let time: Int
    
    /// Timezone given in zoneinfo naming format, eg, "America/Montreal".  DateTimeComponents with a null time zone value represents a point in time in the user's local time zone defined in their device settings.
    public let timeZone: String?
}

extension NSManagedObject {
    /// Use this method in a custom property in an NSManagedObject to store a DateTimeComponents in the NSManagedObject.  Powered internally by Codable and JSON.
    func getDateTimeComponentsForPrimitiveField(forKey key: String) -> DateTimeComponents? {
        self.willAccessValue(forKey: key)
        defer { self.didAccessValue(forKey: key) }
        guard let primitiveValue = primitiveValue(forKey: key) as? Data else {
            return nil
        }
        
        do {
            return try JSONDecoder.default.decode(DateTimeComponents.self, from: primitiveValue)
        } catch {
            os_log("Unable to decode DateTimeComponents stored in core data: %s", log: .persistence, type: .error, String(describing: error))
            return nil
        }
    }
    
    /// Use this method in a custom property in an NSManagedObject to store a DateTimeComponents in the NSManagedObject.  Powered internally by Codable and JSON.
    func setDateTimeComponentsForPrimitiveField(_ newValue: DateTimeComponents?, forKey key: String) {
        willChangeValue(forKey: key)
        defer { didChangeValue(forKey: key) }
        let primitiveValue: Data
        
        guard let newValue = newValue else {
            setPrimitiveValue(nil, forKey: key)
            return
        }
        
        do {
            primitiveValue = try JSONEncoder.default.encode(newValue)
        } catch {
            os_log("Unable to encode predicate for storage in core data: %@", log: .persistence, type: .error, String(describing: error))
            return
        }
        
        setPrimitiveValue(primitiveValue, forKey: key)
    }
}

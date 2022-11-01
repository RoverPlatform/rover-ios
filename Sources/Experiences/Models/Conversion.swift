//
//  Conversion.swift
//  Rover
//
//  Created by Chris Recalis on 2020-06-02.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct Conversion: Decodable {
    public var tag: String
    public var expires: Duration
    
    
    public init(tag: String, expires: Duration) {
        self.tag = tag
        self.expires = expires
    }
}

public struct Duration: Decodable {
    public enum Unit: String, Decodable {
        case seconds = "s"
        case minutes = "m"
        case hours = "h"
        case days = "d"
    }
    
    public var value: Int
    public var unit: Unit
    
    
    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }
    
    public var timeInterval: TimeInterval {
        let base: Int
        switch self.unit {
        case .seconds:
            base = 1
        case .minutes:
            base = 60
        case .hours:
            base = 60 * 60
        case .days:
            base = 24 * 60 * 60
        }
        return TimeInterval(self.value * base)
    }
}

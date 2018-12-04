//
//  EventInfo.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-11-30.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct EventInfo {
    public let name: String
    public let namespace: String?
    
    /// A dictionary of values.
    ///
    /// Note that there are several constraints here not expressed in the Swift type.  Namely, arrays may not be present within dictionaries or other arrays.
    ///
    /// Thus:
    ///
    /// * `String`
    /// * `Int`
    /// * `Double`
    /// * `Bool`
    /// * `[String]`
    /// * `[Int]`
    /// * `[Double]`
    /// * `[Bool]`
    /// * `[String: Any]` (but the `Any` here may not be another dictionary.)
    public let attributes: [String: Any]?
    public let timestamp: Date?
    
    public init(name: String, namespace: String? = nil, attributes: [String: Any]? = nil, timestamp: Date? = nil) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.timestamp = timestamp
    }
}

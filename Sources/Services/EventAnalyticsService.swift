//
//  EventAnalyticsService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-04-30.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os
import UIKit

class EventAnalyticsService {
    let analyticsEndpoint = "https://analytics.rover.io"
    let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    public init() {
        let notificationsByName: [String: RoverNotification] = RoverNotification.allCases.reduce(into: [:]) { (result, notification) in
            result[notification.action] = notification
        }
        
        guard let analyticsUrl = URL(string: analyticsEndpoint) else {
            os_log("Unable to start analytics due to bad endpoint.", log: .rover, type: .error)
            return
        }
    
        func handleRoverNotification(notification: Notification) {
            var urlRequest = URLRequest(url: analyticsUrl)
            urlRequest.httpMethod = "POST"
            guard let accountToken = Rover.accountToken else {
                os_log("Skipping analytics tracking due to Rover.accountToken not yet being set.")
                return
            }
            urlRequest.setAccountToken(accountToken)
            
            guard let roverNotification = notificationsByName[notification.name.rawValue] else {
                os_log("Somehow got unexpected notification name value: %s", notification.name.rawValue)
                return
            }
            
            let eventUpload = EventUpload(
                event: roverNotification.englishName,
                timestamp: "POOP",
                anonymousID: UIDevice.current.identifierForVendor?.uuidString,
                properties: notification.userInfo as? [String: Encodable]
            )
            
            let eventJson: Data
            do {
                eventJson = try JSONEncoder.default.encode(eventUpload)
            } catch {
                os_log("Unable to encode event, because: ", String(describing: error))
                return
            }
            
            urlSession.uploadTask(with: urlRequest, from: eventJson)
        }
        
        RoverNotification.allCases.forEach { notificationType in
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name(roverNotification: notificationType),
                object: nil,
                queue: nil,
                using: handleRoverNotification(notification:)
            )
        }
    }
}

private struct EventUpload: Encodable  {
    enum CodingKeys: String, CodingKey {
        case event
        case timestamp
        case anonymousID
        case properties
    }
    
    public var event: String // "Screen Viewed",
    public var timestamp: String // "2019-01-01T03:00:00Z"
    public var anonymousID: String?
    public var properties: [String: Any]?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.event, forKey: .event)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encode(self.anonymousID, forKey: .anonymousID)
        guard let properties = self.properties else {
            return
        }
        try container.encode(properties, forKey: CodingKeys.event)
    }
}

extension Dictionary: Encodable where Key == String, Value == Any {
    struct CodingKeys: CodingKey {
        var stringValue: String
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int?
        
        init?(intValue: Int) {
            fatalError()
        }
    }

    public func encode(to encoder: Encoder) throws {
        /// nested function for recursing through the dictionary and populating the Encoder with it, doing the necessary type coercions on the way.
        func encodeToContainer(dictionary: [String: Any], container: inout KeyedEncodingContainer<CodingKeys>) throws {
            // This is a set of mappings of types, which makes for a long closure body, so silence the function length warning.
            // swiftlint:disable:next closure_body_length
            try dictionary.forEach { codingKey, value in
                let key = CodingKeys(stringValue: codingKey)
                switch value {
                case let value as Int:
                    try container.encode(value, forKey: key)
                case let value as Bool:
                    try container.encode(value, forKey: key)
                case let value as String:
                    try container.encode(value, forKey: key)
                case let value as Double:
                    try container.encode(value, forKey: key)
                case let value as [Int]:
                    try container.encode(value, forKey: key)
                case let value as [Bool]:
                    try container.encode(value, forKey: key)
                case let value as [Double]:
                    try container.encode(value, forKey: key)
                case let value as [String]:
                    try container.encode(value, forKey: key)
                case let value as [String: Any]:
                    var nestedContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: key)
                    try encodeToContainer(dictionary: value, container: &nestedContainer)
                default:
                    let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unexpected attribute value type. Expected one of Int, String, Double, Boolean, or an array thereof, or a dictionary of all of the above including arrays.")
                    throw EncodingError.invalidValue(value, context)
                }
            }
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try encodeToContainer(dictionary: self, container: &container)
    }
}

private extension RoverNotification {
    var englishName: String {
        switch self {
        case .experiencePresented:
            return "Experience Presented"
        case .experienceDismissed:
            return "Experience Dismissed"
        case .experienceViewed:
            return "Experience Viewed"
        case .screenPresented:
            return "Screen Presented"
        case .screenDismissed:
            return "Screen Dismissed"
        case .screenViewed:
            return "Screen Viewed"
        case .blockTapped:
            return "Block Tapped"
        }
    }
}

//
//  Analytics.swift
//  Rover
//
//  Created by Sean Rucker on 2019-05-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class Analytics {
    static var shared = Analytics()
    
    private let session = URLSession(configuration: URLSessionConfiguration.default)
    private var tokens: [NSObjectProtocol] = []
    
    func enable() {
        guard tokens.isEmpty else {
            return
        }
        
        tokens = [
            NotificationCenter.default.addObserver(
                forName: RoverViewController.experiencePresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Experience Presented", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.experienceDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Experience Dismissed", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.experienceViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Experience Viewed", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.screenPresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Screen Presented", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.screenDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Screen Dismissed", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.screenViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Screen Viewed", userInfo: $0.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RoverViewController.blockTappedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Block Tapped", userInfo: $0.userInfo)
                }
            )
        ]
    }
    
    func disable() {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
    
    deinit {
        disable()
    }
    
    private func trackEvent(name: String, userInfo: [AnyHashable: Any]?) {
        let rawValue: [String: Any] = {
            guard let userInfo = userInfo else {
                return [:]
            }
            
            return userInfo.reduce(into: [:], { (result, element) in
                if let key = element.key as? String {
                    result[key] = element.value
                }
            })
        }()
        
        let properties = Properties(rawValue: rawValue)
        let event = Event(name: name, properties: properties)
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
            data = try encoder.encode(event)
        } catch {
            os_log("Failed to encode event: %@", log: .rover, type: .error, error.localizedDescription)
            return
        }
        
        let url = URL(string: "https://analytics.rover.io")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Rover.accountToken, forHTTPHeaderField: "x-rover-account-token")
        
        session.uploadTask(with: request, from: data).resume()
    }
}

fileprivate struct Event: Encodable {
    let name: String
    let properties: Properties
    let timestamp = Date()
    let anonymousID = UIDevice.current.identifierForVendor?.uuidString
    
    enum CodingKeys: String, CodingKey {
        case name = "event"
        case properties
        case timestamp
        case anonymousID
    }
}

fileprivate struct Properties: Encodable, RawRepresentable {
    let rawValue: [String: Any]
    
    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int?
        
        init?(intValue: Int) {
            fatalError()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try rawValue.forEach { element in
            let key = DynamicCodingKey(stringValue: element.key)
            try container.encode(element.value, forKey: key)
        }
    }
}

fileprivate extension KeyedEncodingContainer {
    mutating func encode(_ value: Any, forKey key: Key) throws {
        switch value {
        case let value as Int:
            try encode(value, forKey: key)
        case let value as Bool:
            try encode(value, forKey: key)
        case let value as String:
            try encode(value, forKey: key)
        case let value as Double:
            try encode(value, forKey: key)
        case let value as [Int]:
            try encode(value, forKey: key)
        case let value as [Bool]:
            try encode(value, forKey: key)
        case let value as [Double]:
            try encode(value, forKey: key)
        case let value as [String]:
            try encode(value, forKey: key)
        case let value as [String: Any]:
            var container = nestedContainer(keyedBy: Key.self, forKey: key)
            try value.forEach { element in
                if let key = Key(stringValue: element.key) {
                    try container.encode(element.value, forKey: key)
                }
            }
        default:
            let context = EncodingError.Context(codingPath: codingPath, debugDescription: "Unexpected value type. Expected one of Int, String, Double, Boolean, or an array thereof, or a dictionary of all of the above including arrays.")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

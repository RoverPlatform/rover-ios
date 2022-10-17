//
//  NotificationTapBehavior.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-06-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum NotificationTapBehavior: Equatable {
    case openApp
    case openURL(url: URL)
    case presentWebsite(url: URL)
}

// MARK: Codable

extension NotificationTapBehavior: Codable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    private enum OpenURLKeys: String, CodingKey {
        case url
    }
    
    private enum PresentWebsiteKeys: String, CodingKey {
        case url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "OpenAppNotificationTapBehavior":
            self = .openApp
        case "OpenURLNotificationTapBehavior":
            let container = try decoder.container(keyedBy: OpenURLKeys.self)
            let url = try container.decode(URL.self, forKey: .url)
            self = .openURL(url: url)
        case "PresentWebsiteNotificationTapBehavior":
            let container = try decoder.container(keyedBy: PresentWebsiteKeys.self)
            let url = try container.decode(URL.self, forKey: .url)
            self = .presentWebsite(url: url)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of OpenAppNotificationTapBehavior, OpenURLNotificationTapBehavior or PresentWebsiteNotificationTapBehavior – found \(typeName)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openApp:
            try container.encode("OpenAppNotificationTapBehavior", forKey: .typeName)
        case .openURL(let url):
            try container.encode("OpenURLNotificationTapBehavior", forKey: .typeName)
            var container = encoder.container(keyedBy: OpenURLKeys.self)
            try container.encode(url, forKey: .url)
        case .presentWebsite(let url):
            try container.encode("PresentWebsiteNotificationTapBehavior", forKey: .typeName)
            var container = encoder.container(keyedBy: PresentWebsiteKeys.self)
            try container.encode(url, forKey: .url)
        }
    }
}

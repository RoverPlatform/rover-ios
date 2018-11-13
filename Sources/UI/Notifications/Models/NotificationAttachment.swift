//
//  NotificationAttachment.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-06-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct NotificationAttachment: Codable, Equatable {
    public enum Format: String, Codable {
        case audio = "AUDIO"
        case image = "IMAGE"
        case video = "VIDEO"
    }
    
    private enum CodingKeys: String, CodingKey {
        case format = "type"
        case url
    }
    
    public var format: Format
    public var url: URL
}

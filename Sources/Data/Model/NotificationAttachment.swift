//
//  NotificationAttachment.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

public class NotificationAttachment: NSObject, Codable, NSCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.format.rawValue, forKey: "format")
        aCoder.encode(self.url, forKey: "url")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let formatString = aDecoder.decodeObject(forKey: "format") as? String else {
            os_log("NotificationAttachment: Format field missing from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        guard let format = Format(rawValue: formatString) else {
            os_log("NotificationAttachment: Invalid format field in NSCoder.", log: .persistence, type: .error)
            return nil
        }
        self.format = format
        guard let urlString = aDecoder.decodeObject(forKey: "url") as? String else {
            os_log("NotificationAttachment: URL field missing from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        guard let url = URL(string: urlString) else {
            os_log("NotificationAttachment: URL field invalid from NSCoder.", log: .persistence, type: .error)
            return nil
        }
        self.url = url
    }
    
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

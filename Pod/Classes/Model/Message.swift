//
//  Message.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-04.
//
//

import Foundation
import CoreData

@objc
public enum Action : Int {
    case None
    case Website
    case LandingPage
    case DeepLink
}

@objc
public class Message : NSObject {
    
    public let identifier: String
    public let title: String?
    public let text: String
    public let timestamp: NSDate
    public let properties: [String: String]
    public var read: Bool = false
    
    public internal(set) var savedToInbox: Bool = false
    public internal(set) var action: Action = .None
    public internal(set) var url: NSURL?
    public internal(set) var landingPage: Screen?
    
    
    init(title: String?, text: String, timestamp: NSDate, identifier: String, properties: [String: String]) {
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.identifier = identifier
        self.properties = properties
        
        super.init()
    }
}
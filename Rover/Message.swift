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
    case none
    case website
    case landingPage
    case deepLink
    case experience
}

@objc
open class Message : NSObject {
    
    open let identifier: String
    open let title: String?
    open let text: String
    open let timestamp: Date
    open let properties: [String: String]
    open var read: Bool = false
    
    open internal(set) var savedToInbox: Bool = false
    open internal(set) var action: Action = .none
    open internal(set) var url: URL?
    open internal(set) var landingPage: Screen?
    open internal(set) var experienceId: String?
    
    init(title: String?, text: String, timestamp: Date, identifier: String, properties: [String: String]) {
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.identifier = identifier
        self.properties = properties
        
        super.init()
    }
}

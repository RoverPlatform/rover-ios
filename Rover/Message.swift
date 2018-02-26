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
    
    @objc open let identifier: String
    @objc open let title: String?
    @objc open let text: String
    @objc open let timestamp: Date
    @objc open let properties: [String: String]
    @objc open var read: Bool = false
    
    @objc open internal(set) var savedToInbox: Bool = false
    @objc open internal(set) var action: Action = .none
    @objc open internal(set) var url: URL?
    @objc open internal(set) var landingPage: Screen?
    @objc open internal(set) var experienceId: String?
    
    init(title: String?, text: String, timestamp: Date, identifier: String, properties: [String: String]) {
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.identifier = identifier
        self.properties = properties
        
        super.init()
    }
}

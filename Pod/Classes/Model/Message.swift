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
    case Link
    case LandingPage
}

@objc
public class Message : NSObject {
    
    public let identifier: String
    public let title: String?
    public let text: String
    public let timestamp: NSDate
    public var read: Bool = false
    
    public internal(set) var action: Action = .None
    public internal(set) var url: NSURL?
    public internal(set) var landingPage: Screen?
    
    
    init(title: String?, text: String, timestamp: NSDate, identifier: String) {
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.identifier = identifier
        
        super.init()
    }
}
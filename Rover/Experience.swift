//
//  Experience.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-08.
//
//

import Foundation

open class Experience : NSObject {
    open let identifier: String
    open let screens: [Screen]
    open let homeScreenIdentifier: String
    open var version: String?
    open var customKeys = [String: String]()
    
    var homeScreen: Screen? {
        return screens.filter { $0.identifier == self.homeScreenIdentifier }.first
    }
    
    init(screens: [Screen], homeScreenIdentifier: String, identifier: String) {
        self.screens = screens
        self.homeScreenIdentifier = homeScreenIdentifier
        self.identifier = identifier
    }
}

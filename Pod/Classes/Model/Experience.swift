//
//  Experience.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-08.
//
//

import Foundation

public class Experience {
    let identifier: String
    let screens: [Screen]
    let homeScreenIdentifier: String
    
    var homeScreen: Screen? {
        return screens.filter { $0.identifier == self.homeScreenIdentifier }.first
    }
    
    init(screens: [Screen], homeScreenIdentifier: String, identifier: String) {
        self.screens = screens
        self.homeScreenIdentifier = homeScreenIdentifier
        self.identifier = identifier
    }
}
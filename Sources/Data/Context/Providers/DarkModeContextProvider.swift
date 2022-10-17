//
//  DarkModeContextProvider.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-09-09.
//

import Foundation

public protocol DarkModeContextProvider: AnyObject {
    var isDarkModeEnabled: Bool? { get }
}

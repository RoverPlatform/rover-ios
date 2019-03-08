//
//  LocaleContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol LocaleContextProvider: AnyObject {
    var localeLanguage: String? { get }
    var localeRegion: String? { get }
    var localeScript: String? { get }
}

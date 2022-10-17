//
//  ConversionsContextProvider.swift
//  RoverCampaigns
//
//  Created by Chris Recalis on 2020-06-25.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

public protocol ConversionsContextProvider: AnyObject {
    var conversions: [String]? { get }
}

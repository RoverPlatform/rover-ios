//
//  UserInfoContextProvider.swift
//  RoverCampaignsData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import RoverCampaignsFoundation

public protocol UserInfoContextProvider: AnyObject {
    var userInfo: Attributes? { get }
}

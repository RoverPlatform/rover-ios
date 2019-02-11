//
//  SyncResult.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

enum SyncResult {
    case newData(nextRequestVariables: [String: Any]?)
    case noData
    case failed
}

//
//  SyncResult.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public enum SyncResult {
    case newData(nextRequest: SyncRequest?)
    case noData
    case failed
}

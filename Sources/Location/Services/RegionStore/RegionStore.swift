//
//  RegionStore.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol RegionStore {
    var regions: Set<Region> { get }
    
    func addObserver(block: @escaping (Set<Region>) -> Void) -> NSObjectProtocol
    func removeObserver(_ token: NSObjectProtocol)
    func fetchRegions(completionHandler: ((FetchRegionsResult) -> Void)?)
}

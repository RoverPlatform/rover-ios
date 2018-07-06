//
//  FetchRegionsResult.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public enum FetchRegionsResult {
    case error(error: Error?, isRetryable: Bool)
    case success(regions: Set<Region>)
}

//
//  PageInfo.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct PageInfo: Codable {
    public var endCursor: String?
    public var hasNextPage: Bool
    
    public init(endCursor: String?, hasNextPage: Bool) {
        self.endCursor = endCursor
        self.hasNextPage = hasNextPage
    }
}

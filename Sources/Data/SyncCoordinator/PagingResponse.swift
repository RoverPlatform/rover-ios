//
//  PagingResponse.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol PagingResponse: Decodable {
    associatedtype Node

    var nodes: [Node]? { get }
    var pageInfo: PageInfo { get }
}

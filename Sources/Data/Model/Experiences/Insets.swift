//
//  Insets.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Insets: Decodable {
    public var bottom: Int
    public var left: Int
    public var right: Int
    public var top: Int
    
    public init(bottom: Int, left: Int, right: Int, top: Int) {
        self.bottom = bottom
        self.left = left
        self.right = right
        self.top = top
    }
}

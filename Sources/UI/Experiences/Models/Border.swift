//
//  Border.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-04-13.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Border: Decodable {
    public var color: Color
    public var radius: Int
    public var width: Int
    
    public init(color: Color, radius: Int, width: Int) {
        self.color = color
        self.radius = radius
        self.width = width
    }
}

//
//  Color.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct Color: Decodable {
    public var red: Int
    public var green: Int
    public var blue: Int
    public var alpha: Double
    
    public init(red: Int, green: Int, blue: Int, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

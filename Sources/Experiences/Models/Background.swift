//
//  Background.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct Background: Decodable {
    public enum ContentMode: String, Decodable {
        case original = "ORIGINAL"
        case stretch = "STRETCH"
        case tile = "TILE"
        case fill = "FILL"
        case fit = "FIT"
    }
    
    public enum Scale: String, Decodable {
        case x1 = "X1"
        case x2 = "X2"
        case x3 = "X3"
    }
    
    public var color: Color
    public var contentMode: ContentMode
    public var image: Image?
    public var scale: Scale
    
    public init(color: Color, contentMode: ContentMode, image: Image?, scale: Scale) {
        self.color = color
        self.contentMode = contentMode
        self.image = image
        self.scale = scale
    }
}

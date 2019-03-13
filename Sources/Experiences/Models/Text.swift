//
//  Text.swift
//  Rover
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct Text: Decodable {
    public enum Alignment: String, Decodable {
        case center = "CENTER"
        case left = "LEFT"
        case right = "RIGHT"
    }
    
    public struct Font: Decodable {
        public enum Weight: String, Decodable {
            case ultraLight = "ULTRA_LIGHT"
            case thin = "THIN"
            case light = "LIGHT"
            case regular = "REGULAR"
            case medium = "MEDIUM"
            case semiBold = "SEMI_BOLD"
            case bold = "BOLD"
            case heavy = "HEAVY"
            case black = "BLACK"
        }
        
        public var size: Int
        public var weight: Weight
        
        public init(size: Int, weight: Weight) {
            self.size = size
            self.weight = weight
        }
    }
    
    public var rawValue: String
    public var alignment: Alignment
    public var color: Color
    public var font: Font
    
    public init(rawValue: String, alignment: Alignment, color: Color, font: Font) {
        self.rawValue = rawValue
        self.alignment = alignment
        self.color = color
        self.font = font
    }
}

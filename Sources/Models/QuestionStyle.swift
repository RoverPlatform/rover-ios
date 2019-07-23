//
//  QuestionStyle.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-17.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

// TODO: doomed
public struct QuestionStyle: Decodable {
    public var color: Color
    public var font: Text.Font
    public var textAlignment: Text.Alignment
    
    public init(color: Color, font: Text.Font, textAlignment: Text.Alignment) {
        self.color = color
        self.font = font
        self.textAlignment = textAlignment
    }
}

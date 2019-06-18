//
//  TextPollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct TextPollBlock : PollBlock {
    public struct OptionStyle: Decodable {
        public var height: Int
        public var opacity: Double
        public var borderRadius: Int
        public var borderWidth: Int
        public var borderColor: Color
        public var color: Color
        public var font: Text.Font
        public var textAlignment: Text.Alignment
        public var resultFillColor: Color
        public var background: Background
        public var verticalSpacing: Int
        
        public init(height: Int, opacity: Double, borderRadius: Int, borderWidth: Int, borderColor: Color, color: Color, font: Text.Font, textAlignment: Text.Alignment, resultFillColor: Color, background: Background, verticalSpacing: Int) {
            self.height = height
            self.opacity = opacity
            self.borderRadius = borderRadius
            self.borderWidth = borderWidth
            self.borderColor = borderColor
            self.color = color
            self.font = font
            self.textAlignment = textAlignment
            self.resultFillColor = resultFillColor
            self.background = background
            self.verticalSpacing = verticalSpacing
        }
    }
    
    // MARK: Block fields
    public var background: Background
    public var border: Border
    public var id: String
    public var name: String
    public var insets: Insets
    public var opacity: Double
    public var position: Position
    public var tapBehavior: BlockTapBehavior
    public var keys: [String : String]
    public var tags: [String]
    
    // MARK: Text Poll fields
    public var question: String
    public var options: [String]
    public var questionStyle: QuestionStyle
    public var optionStyle: OptionStyle
    
    public init(background: Background, border: Border, id: String, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, keys: [String: String], tags: [String], question: String, options: [String], questionStyle: QuestionStyle, optionStyle: OptionStyle) {
        self.background = background
        self.border = border
        self.id = id
        self.name = name
        self.insets = insets
        self.opacity = opacity
        self.position = position
        self.tapBehavior = tapBehavior
        self.keys = keys
        self.tags = tags
        self.options = options
        self.question = question
        self.questionStyle = questionStyle
        self.optionStyle = optionStyle
    }
}

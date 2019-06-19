//
//  ImagePollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-17.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct ImagePollBlock : PollBlock {
    public struct OptionStyle: Decodable {
        public var opacity: Double
        public var color: Color
        public var border: Border
        public var font: Text.Font
        public var textAlignment: Text.Alignment
        public var resultFillColor: Color
        public var verticalSpacing: Int
        public var horizontalSpacing: Int

        public init(opacity: Double, color: Color, border: Border, font: Text.Font, textAlignment: Text.Alignment, resultFillColor: Color, verticalSpacing: Int, horizontalSpacing: Int) {
            self.opacity = opacity
            self.color = color
            self.border = border
            self.font = font
            self.textAlignment = textAlignment
            self.resultFillColor = resultFillColor
            self.verticalSpacing = verticalSpacing
            self.horizontalSpacing = horizontalSpacing
        }
    }
    
    public struct Option: Decodable {
        public var text: String
        public var image: Image
        
        public init(text: String, image: Image) {
            self.text = text
            self.image = image
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
    
    // MARK: Image Poll fields
    public var question: String
    public var options: [Option]
    public var questionStyle: QuestionStyle
    public var optionStyle: OptionStyle
    
    public init(background: Background, border: Border, id: String, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, keys: [String: String], tags: [String], question: String, options: [Option], questionStyle: QuestionStyle, optionStyle: OptionStyle) {
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

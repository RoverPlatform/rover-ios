//
//  TextPollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct TextPollBlock: PollBlock {
    // MARK: Text Poll fields
    
    public struct TextPoll: Decodable {
        public struct Option: Decodable {
            public var id: String
            public var height: Int
            public var opacity: Double
            public var border: Border
            public var text: Text
            public var resultFillColor: Color
            public var background: Background
            public var topMargin: Int
            
            public init(id: String, height: Int, opacity: Double, border: Border, text: Text, resultFillColor: Color, background: Background, topMargin: Int) {
                self.id = id
                self.height = height
                self.opacity = opacity
                self.border = border
                self.text = text
                self.resultFillColor = resultFillColor
                self.background = background
                self.topMargin = topMargin
            }
        }
    
        public var question: Text
        public var options: [Option]
        
        public init(question: Text, options: [Option]) {
            self.question = question
            self.options = options
        }
    }
    
    public var textPoll: TextPoll
    
    // MARK: Block fields
    public var background: Background
    public var border: Border
    public var id: String
    public var name: String
    public var insets: Insets
    public var opacity: Double
    public var position: Position
    public var tapBehavior: BlockTapBehavior
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: Background, border: Border, id: String, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, keys: [String: String], tags: [String], textPoll: TextPoll) {
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
        self.textPoll = textPoll
    }
}

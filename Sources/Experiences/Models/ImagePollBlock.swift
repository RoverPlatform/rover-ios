//
//  ImagePollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-17.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct ImagePollBlock: Block {
    // MARK: Image Poll fields
    
    public struct ImagePoll: Decodable {
        public struct Option: Decodable {
            public var id: String
            public var text: Text
            public var image: Image?
            public var background: Background
            public var border: Border
            public var opacity: Double
            public var topMargin: Int
            public var leftMargin: Int
            public var resultFillColor: Color
            
            public init(
                id: String, text: Text, image: Image, background: Background, border: Border, opacity: Double, topMargin: Int, leftMargin: Int, resultFillColor: Color
            ) {
                self.id = id
                self.text = text
                self.image = image
                self.background = background
                self.border = border
                self.opacity = opacity
                self.topMargin = topMargin
                self.leftMargin = leftMargin
                self.resultFillColor = resultFillColor
            }
        }
        
        public var question: Text
        public var options: [Option]
        
        public init(question: Text, options: [Option]) {
            self.question = question
            self.options = options
        }
    }
    
    public var imagePoll: ImagePoll

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
    public var conversion: Conversion?

    
    public init(background: Background, border: Border, id: String, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, keys: [String: String], tags: [String], imagePoll: ImagePoll, conversion: Conversion?) {
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
        self.imagePoll = imagePoll
        self.conversion = conversion
    }
}

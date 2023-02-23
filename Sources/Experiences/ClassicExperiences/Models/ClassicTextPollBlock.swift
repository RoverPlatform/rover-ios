// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

public struct ClassicTextPollBlock: ClassicBlock {
    // MARK: Text Poll fields
    
    public struct TextPoll: Decodable {
        public struct Option: Decodable {
            public var id: String
            public var height: Int
            public var opacity: Double
            public var border: ClassicBorder
            public var text: ClassicText
            public var resultFillColor: ClassicColor
            public var background: ClassicBackground
            public var topMargin: Int
            
            public init(id: String, height: Int, opacity: Double, border: ClassicBorder, text: ClassicText, resultFillColor: ClassicColor, background: ClassicBackground, topMargin: Int) {
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
    
        public var question: ClassicText
        public var options: [Option]
        
        public init(question: ClassicText, options: [Option]) {
            self.question = question
            self.options = options
        }
    }
    
    public var textPoll: TextPoll
    
    // MARK: Block fields
    public var background: ClassicBackground
    public var border: ClassicBorder
    public var id: String
    public var name: String
    public var insets: ClassicInsets
    public var opacity: Double
    public var position: ClassicPosition
    public var tapBehavior: ClassicBlockTapBehavior
    public var keys: [String: String]
    public var tags: [String]
    public var conversion: ClassicConversion?

    
    public init(background: ClassicBackground, border: ClassicBorder, id: String, name: String, insets: ClassicInsets, opacity: Double, position: ClassicPosition, tapBehavior: ClassicBlockTapBehavior, keys: [String: String], tags: [String], textPoll: TextPoll, conversion: ClassicConversion?) {
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
        self.conversion = conversion

    }
}

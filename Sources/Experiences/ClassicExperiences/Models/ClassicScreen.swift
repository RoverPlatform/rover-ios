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

public struct ClassicScreen: Decodable {
    public struct StatusBar: Decodable {
        public enum Style: String, Decodable {
            case dark = "DARK"
            case light = "LIGHT"
        }

        public var style: Style
        public var color: ClassicColor
        
        public init(style: Style, color: ClassicColor) {
            self.style = style
            self.color = color
        }
    }
    
    public struct TitleBar: Decodable {
        public enum Buttons: String, Decodable {
            case close = "CLOSE"
            case back = "BACK"
            case both = "BOTH"
        }
        
        public var backgroundColor: ClassicColor
        public var buttons: Buttons
        public var buttonColor: ClassicColor
        public var text: String
        public var textColor: ClassicColor
        public var useDefaultStyle: Bool
        
        public init(backgroundColor: ClassicColor, buttons: Buttons, buttonColor: ClassicColor, text: String, textColor: ClassicColor, useDefaultStyle: Bool) {
            self.backgroundColor = backgroundColor
            self.buttons = buttons
            self.buttonColor = buttonColor
            self.text = text
            self.textColor = textColor
            self.useDefaultStyle = useDefaultStyle
        }
    }
    
    public var background: ClassicBackground
    public var id: String
    public var name: String
    public var isStretchyHeaderEnabled: Bool
    public var rows: [ClassicRow]
    public var statusBar: StatusBar
    public var titleBar: TitleBar
    public var keys: [String: String]
    public var tags: [String]
    public var conversion: ClassicConversion?
    
    public init(background: ClassicBackground, id: String, name: String, isStretchyHeaderEnabled: Bool, rows: [ClassicRow], statusBar: StatusBar, titleBar: TitleBar, keys: [String: String], tags: [String], conversion: ClassicConversion?) {
        self.background = background
        self.id = id
        self.name = name
        self.isStretchyHeaderEnabled = isStretchyHeaderEnabled
        self.rows = rows
        self.statusBar = statusBar
        self.titleBar = titleBar
        self.keys = keys
        self.tags = tags
        self.conversion = conversion
    }
}

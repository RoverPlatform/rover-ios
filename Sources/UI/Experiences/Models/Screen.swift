//
//  Screen.swift
//  RoverUI
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct Screen: Decodable {
    public struct StatusBar: Decodable {
        public enum Style: String, Decodable {
            case dark = "DARK"
            case light = "LIGHT"
        }

        public var style: Style
        public var color: Color
        
        public init(style: Style, color: Color) {
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
        
        public var backgroundColor: Color
        public var buttons: Buttons
        public var buttonColor: Color
        public var text: String
        public var textColor: Color
        public var useDefaultStyle: Bool
        
        public init(backgroundColor: Color, buttons: Buttons, buttonColor: Color, text: String, textColor: Color, useDefaultStyle: Bool) {
            self.backgroundColor = backgroundColor
            self.buttons = buttons
            self.buttonColor = buttonColor
            self.text = text
            self.textColor = textColor
            self.useDefaultStyle = useDefaultStyle
        }
    }
    
    public var background: Background
    public var id: String
    public var name: String
    public var isStretchyHeaderEnabled: Bool
    public var rows: [Row]
    public var statusBar: StatusBar
    public var titleBar: TitleBar
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: Background, id: String, name: String, isStretchyHeaderEnabled: Bool, rows: [Row], statusBar: StatusBar, titleBar: TitleBar, keys: [String: String], tags: [String]) {
        self.background = background
        self.id = id
        self.name = name
        self.isStretchyHeaderEnabled = isStretchyHeaderEnabled
        self.rows = rows
        self.statusBar = statusBar
        self.titleBar = titleBar
        self.keys = keys
        self.tags = tags
    }
}

// MARK: Attributes

extension Screen {
    public var attributes: Attributes {
        let keys = self.keys.reduce(into: Attributes()) { $0[$1.0] = $1.1 }
        return [
            "id": id,
            "name": name,
            "keys": AttributeValue.object(keys),
            "tags": tags
        ]
    }
}

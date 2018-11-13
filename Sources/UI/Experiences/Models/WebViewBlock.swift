//
//  WebViewBlock.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct WebViewBlock: Block {
    public var background: Background
    public var border: Border
    public var id: ID
    public var name: String
    public var insets: Insets
    public var opacity: Double
    public var position: Position
    public var tapBehavior: BlockTapBehavior
    public var webView: WebView
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: Background, border: Border, id: ID, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, webView: WebView, keys: [String: String], tags: [String]) {
        self.background = background
        self.border = border
        self.id = id
        self.name = name
        self.insets = insets
        self.opacity = opacity
        self.position = position
        self.tapBehavior = tapBehavior
        self.webView = webView
        self.keys = keys
        self.tags = tags
    }
}

//
//  Image.swift
//  Rover
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct Image: Decodable {
    public var height: Int
    public var isURLOptimizationEnabled: Bool
    public var name: String
    public var size: Int
    public var width: Int
    public var url: URL
    public var accessibilityLabel: String?
    public var isDecorative: Bool
    
    public init(height: Int, isURLOptimizationEnabled: Bool, name: String, size: Int, width: Int, url: URL, accessibilityLabel: String?, isDecorative: Bool) {
        self.height = height
        self.isURLOptimizationEnabled = isURLOptimizationEnabled
        self.name = name
        self.size = size
        self.width = width
        self.url = url
        self.accessibilityLabel = accessibilityLabel
        self.isDecorative = isDecorative
    }
}

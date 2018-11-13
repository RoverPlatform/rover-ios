//
//  WebView.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct WebView: Decodable {
    public var isScrollingEnabled: Bool
    public var url: URL
    
    public init(isScrollingEnabled: Bool, url: URL) {
        self.isScrollingEnabled = isScrollingEnabled
        self.url = url
    }
}

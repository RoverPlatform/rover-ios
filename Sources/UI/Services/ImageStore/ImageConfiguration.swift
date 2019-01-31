//
//  ImageConfiguration.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreGraphics
import Foundation

public struct ImageConfiguration {
    public let url: URL
    public let optimization: ImageOptimization?
    
    public var optimizedURL: URL {
        guard let optimization = optimization else {
            return url
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        var temp = urlComponents.queryItems ?? [URLQueryItem]()
        temp += optimization.queryItems
        urlComponents.queryItems = temp
        return urlComponents.url ?? url
    }
    
    public var scale: CGFloat {
        return optimization?.scale ?? 1
    }
    
    public init(url: URL, optimization: ImageOptimization? = nil) {
        self.url = url
        self.optimization = optimization
    }
}

extension ImageConfiguration: Equatable {
    public static func == (lhs: ImageConfiguration, rhs: ImageConfiguration) -> Bool {
        return lhs.optimizedURL == rhs.optimizedURL
    }
}

extension ImageConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(optimizedURL.hashValue)
    }
}

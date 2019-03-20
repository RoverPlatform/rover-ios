//
//  ImageConfiguration.swift
//  Rover
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

// MARK: Convenience Initializers

extension ImageConfiguration {
    public init?(background: Background, frame: CGRect) {
        guard let image = background.image else {
            return nil
        }
        
        let optimization: ImageOptimization?
        if image.isURLOptimizationEnabled {
            let originalSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            
            let originalScale: CGFloat
            switch background.scale {
            case .x1:
                originalScale = 1
            case .x2:
                originalScale = 2
            case .x3:
                originalScale = 3
            }
            
            switch background.contentMode {
            case .fill:
                optimization = .fill(bounds: frame)
            case .fit:
                optimization = .fit(bounds: frame)
            case .stretch:
                optimization = .stretch(bounds: frame, originalSize: originalSize)
            case .original:
                optimization = .original(bounds: frame, originalSize: originalSize, originalScale: originalScale)
            case .tile:
                optimization = .tile(bounds: frame, originalSize: originalSize, originalScale: originalScale)
            }
        } else {
            optimization = nil
        }
        
        self.init(url: image.url, optimization: optimization)
    }
    
    public init(image: Image, frame: CGRect) {
        let originalSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let optimization = ImageOptimization.stretch(bounds: frame, originalSize: originalSize)
        self.init(url: image.url, optimization: optimization)
    }
}

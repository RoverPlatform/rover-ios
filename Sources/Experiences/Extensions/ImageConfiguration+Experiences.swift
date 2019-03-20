//
//  ImageConfiguration+Experiences.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreGraphics

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

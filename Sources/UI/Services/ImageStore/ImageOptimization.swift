//
//  ImageOptimization.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public enum ImageOptimization {
    var queryItems: [URLQueryItem] {
        switch self {
        case .fill(let bounds):
            let w = bounds.width * UIScreen.main.scale
            let h = bounds.height * UIScreen.main.scale
            return [URLQueryItem(name: "fit", value: "min"), URLQueryItem(name: "w", value: w.paramValue), URLQueryItem(name: "h", value: h.paramValue)]
        case .fit(let bounds):
            let w = bounds.width * UIScreen.main.scale
            let h = bounds.height * UIScreen.main.scale
            return [URLQueryItem(name: "fit", value: "max"), URLQueryItem(name: "w", value: w.paramValue), URLQueryItem(name: "h", value: h.paramValue)]
        case let .stretch(bounds, originalSize):
            let w = min(bounds.width * UIScreen.main.scale, originalSize.width)
            let h = min(bounds.height * UIScreen.main.scale, originalSize.height)
            return [URLQueryItem(name: "w", value: w.paramValue), URLQueryItem(name: "h", value: h.paramValue)]
        case let .original(bounds, originalSize, originalScale):
            let width = min(bounds.width * originalScale, originalSize.width)
            let height = min(bounds.height * originalScale, originalSize.height)
            let x = (originalSize.width - width) / 2
            let y = (originalSize.height - height) / 2
            let value = [x.paramValue, y.paramValue, width.paramValue, height.paramValue].joined(separator: ",")
            var queryItems = [URLQueryItem(name: "rect", value: value)]
            
            if UIScreen.main.scale < originalScale {
                let w = width / originalScale * UIScreen.main.scale
                let h = height / originalScale * UIScreen.main.scale
                queryItems.append(contentsOf: [URLQueryItem(name: "w", value: w.paramValue), URLQueryItem(name: "h", value: h.paramValue)])
            }
            
            return queryItems
        case let .tile(bounds, originalSize, originalScale):
            let width = min(bounds.width * originalScale, originalSize.width)
            let height = min(bounds.height * originalScale, originalSize.height)
            let value = ["0", "0", width.paramValue, height.paramValue].joined(separator: ",")
            var queryItems = [URLQueryItem(name: "rect", value: value)]
            
            if UIScreen.main.scale < originalScale {
                let w = width / originalScale * UIScreen.main.scale
                let h = height / originalScale * UIScreen.main.scale
                queryItems.append(contentsOf: [URLQueryItem(name: "w", value: w.paramValue), URLQueryItem(name: "h", value: h.paramValue)])
            }
            
            return queryItems
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .original(_, _, let originalScale):
            return UIScreen.main.scale < originalScale ? UIScreen.main.scale : originalScale
        case .tile(_, _, let originalScale):
            return UIScreen.main.scale < originalScale ? UIScreen.main.scale : originalScale
        default:
            return 1
        }
    }
    
    case fill(bounds: CGRect)
    case fit(bounds: CGRect)
    case stretch(bounds: CGRect, originalSize: CGSize)
    case original(bounds: CGRect, originalSize: CGSize, originalScale: CGFloat)
    case tile(bounds: CGRect, originalSize: CGSize, originalScale: CGFloat)
}

// MARK: CGFloat

fileprivate extension CGFloat {
    var paramValue: String {
        let rounded = self.rounded()
        let int = Int(rounded)
        return int.description
    }
}

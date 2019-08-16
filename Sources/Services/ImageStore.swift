//
//  ImageStore.swift
//  Rover
//
//  Created by Sean Rucker on 2018-04-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class ImageStore {
    /// The shared singleton image store.
    static let shared = ImageStore()
    
    // MARK: Cache
    
    fileprivate enum Optimization: Equatable, Hashable {
        case fill(bounds: CGRect)
        case fit(bounds: CGRect)
        case stretch(bounds: CGRect, originalSize: CGSize)
        case original(bounds: CGRect, originalSize: CGSize, originalScale: CGFloat)
        case tile(bounds: CGRect, originalSize: CGSize, originalScale: CGFloat)
    }
    
    fileprivate struct Configuration: Equatable, Hashable {
        let url: URL
        let optimization: Optimization?
    }
    
    private class CacheKey: NSObject {
        let configuration: Configuration
        
        init(configuration: Configuration) {
            self.configuration = configuration
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? CacheKey else {
                return false
            }
            
            let lhs = self
            return lhs.configuration == rhs.configuration
        }
        
        override var hash: Int {
            return configuration.hashValue
        }
    }
    
    private var cache = NSCache<CacheKey, UIImage>()
    
    /// Return the `UIImage` for the given background model from cache, provided that it has already been retrieved once
    /// in this session. Returns nil if the image is not present in the cache.
    func image(for background: Background, frame: CGRect) -> UIImage? {
        guard let configuration = Configuration(background: background, frame: frame) else {
            return nil
        }
        
        return image(for: configuration)
    }
    
    /// Return the `UIImage` for the given image model from cache, provided that it has already been retrieved once in
    /// this session. Returns nil if the image is not present in the cache.
    func image(for image: Image, frame: CGRect) -> UIImage? {
        let configuration = Configuration(image: image, frame: frame)
        return self.image(for: configuration)
    }
    
    func image(for image: Image, filledInFrame frame: CGRect) -> UIImage? {
        let optimization: ImageStore.Optimization = .fill(bounds: frame)
        let configuration = Configuration(url: image.url, optimization: optimization)
        return self.image(for: configuration)
    }
    
    private func image(for configuration: Configuration) -> UIImage? {
        let key = CacheKey(configuration: configuration)
        return cache.object(forKey: key)
    }
    
    // MARK: Fetching
    
    private let session = URLSession(configuration: .default)
    private var tasks = [Configuration: URLSessionTask]()
    private var completionHandlers = [Configuration: [(UIImage?) -> Void]]()
    
    /// Fetch a `UIImage` for the given background model from Rover's servers.
    ///
    /// Before making a network request the image store will first attempt to retreive the image from its cache and will
    /// return the cache result if found.
    func fetchImage(for background: Background, frame: CGRect, completionHandler: ((UIImage?) -> Void)? = nil) {
        guard let configuration = ImageStore.Configuration(background: background, frame: frame) else {
            completionHandler?(nil)
            return
        }
        
        fetchImage(for: configuration, completionHandler: completionHandler)
    }
    
    /// Fetch a `UIImage` for the given image model from Rover's servers.
    ///
    /// Before making a network request the image store will first attempt to retreive the image from its cache and will
    /// return the cache result if found.
    func fetchImage(for image: Image, frame: CGRect, completionHandler: ((UIImage?) -> Void)? = nil) {
        let configuration = Configuration(image: image, frame: frame)
        fetchImage(for: configuration, completionHandler: completionHandler)
    }
    
    func fetchImage(for image: Image, filledInFrame frame: CGRect, completionHandler: ((UIImage?) -> Void)? = nil) {
        let optimization: ImageStore.Optimization = .fill(bounds: frame)
        let configuration = Configuration(url: image.url, optimization: optimization)
        fetchImage(for: configuration, completionHandler: completionHandler)
    }
    
    private func fetchImage(for configuration: Configuration, completionHandler: ((UIImage?) -> Void)? = nil) {
        if !Thread.isMainThread {
            os_log("ImageStore is not thread-safe – fetchImage only be called from main thread", log: .rover, type: .default)
        }
        
        if let newHandler = completionHandler {
            let existingHandlers = self.completionHandlers[configuration, default: []]
            completionHandlers[configuration] = existingHandlers + [newHandler]
        }
        
        if tasks[configuration] != nil {
            return
        }
        
        if let image = image(for: configuration) {
            invokeCompletionHandlers(for: configuration, with: image)
            return
        }
        
        let task = session.dataTask(with: configuration.optimizedURL) { data, _, _ in
            if let data = data, let image = UIImage(data: data, scale: configuration.scale) {
                let key = CacheKey(configuration: configuration)
                self.cache.setObject(image, forKey: key)
                
                DispatchQueue.main.async {
                    self.tasks[configuration] = nil
                    self.invokeCompletionHandlers(for: configuration, with: image)
                }
            } else {
                DispatchQueue.main.async {
                    self.tasks[configuration] = nil
                }
            }
        }
        
        tasks[configuration] = task
        task.resume()
    }
    
    private func invokeCompletionHandlers(for configuration: Configuration, with fetchedImage: UIImage) {
        let completionHandlers = self.completionHandlers[configuration, default: []]
        self.completionHandlers[configuration] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(fetchedImage)
        }
    }
}

extension ImageStore.Configuration {
    var optimizedURL: URL {
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
    
    var scale: CGFloat {
        return optimization?.scale ?? 1
    }
    
    init?(background: Background, frame: CGRect) {
        guard let image = background.image else {
            return nil
        }
        
        let optimization: ImageStore.Optimization?
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
    
    init(image: Image, frame: CGRect) {
        let originalSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let optimization = ImageStore.Optimization.stretch(bounds: frame, originalSize: originalSize)
        self.init(url: image.url, optimization: optimization)
    }
}

extension ImageStore.Optimization {
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
}

fileprivate extension CGFloat {
    var paramValue: String {
        let rounded = self.rounded()
        let int = Int(rounded)
        return int.description
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

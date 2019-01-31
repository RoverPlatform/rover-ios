//
//  ImageStoreService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class ImageStoreService: ImageStore {
    let session: URLSession
    
    var tasks = [ImageConfiguration: URLSessionTask]()
    var completionHandlers = [ImageConfiguration: [(UIImage?) -> Void]]()
    
    class CacheKey: NSObject {
        let imageConfiguration: ImageConfiguration
        
        init(imageConfiguration: ImageConfiguration) {
            self.imageConfiguration = imageConfiguration
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? CacheKey else {
                return false
            }
            
            let lhs = self
            return lhs.imageConfiguration == rhs.imageConfiguration
        }
        
        override var hash: Int {
            return imageConfiguration.hashValue
        }
    }
    
    var cache = NSCache<CacheKey, UIImage>()
    
    init(session: URLSession) {
        self.session = session
    }
    
    func fetchImage(for configuration: ImageConfiguration, completionHandler: ((UIImage?) -> Void)?) {
        if !Thread.isMainThread {
            os_log("ImageStoreService is not thread-safe – fetchImage only be called from main thread", log: .general, type: .default)
        }
        
        if let newHandler = completionHandler {
            let existingHandlers = self.completionHandlers[configuration, default: []]
            self.completionHandlers[configuration] = existingHandlers + [newHandler]
        }
        
        if tasks[configuration] != nil {
            return
        }
        
        if let image = fetchedImage(for: configuration) {
            invokeCompletionHandlers(for: configuration, with: image)
        } else {
            let task = session.dataTask(with: configuration.optimizedURL) { data, _, _ in
                if let data = data, let image = UIImage(data: data, scale: configuration.scale) {
                    let key = CacheKey(imageConfiguration: configuration)
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
    }
    
    func fetchedImage(for configuration: ImageConfiguration) -> UIImage? {
        let key = CacheKey(imageConfiguration: configuration)
        return cache.object(forKey: key)
    }
        
    func invokeCompletionHandlers(for configuration: ImageConfiguration, with fetchedImage: UIImage) {
        let completionHandlers = self.completionHandlers[configuration, default: []]
        self.completionHandlers[configuration] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(fetchedImage)
        }
    }
}

//
//  ImageStoreService.swift
//  Rover
//
//  Created by Sean Rucker on 2018-04-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

public class ImageStoreService: ImageStore {
    let session: URLSession
    
    var tasks = [ImageConfiguration: URLSessionTask]()
    var completionHandlers = [ImageConfiguration: [(UIImage?) -> Void]]()
    
    public init(session: URLSession) {
        self.session = session
    }
    
    public func fetchImage(for configuration: ImageConfiguration, completionHandler: ((UIImage?) -> Void)?) {
        if !Thread.isMainThread {
            os_log("ImageStoreService is not thread-safe – fetchImage only be called from main thread", log: .rover, type: .default)
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
                    let key = ImageCache.Key(imageConfiguration: configuration)
                    ImageCache.shared.setObject(image, forKey: key)
                    
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
    
    public func fetchedImage(for configuration: ImageConfiguration) -> UIImage? {
        let key = ImageCache.Key(imageConfiguration: configuration)
        return ImageCache.shared.object(forKey: key)
    }
        
    public func invokeCompletionHandlers(for configuration: ImageConfiguration, with fetchedImage: UIImage) {
        let completionHandlers = self.completionHandlers[configuration, default: []]
        self.completionHandlers[configuration] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(fetchedImage)
        }
    }
}

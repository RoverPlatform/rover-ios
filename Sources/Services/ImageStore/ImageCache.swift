//
//  ImageCache.swift
//  Rover
//
//  Created by Sean Rucker on 2019-03-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

enum ImageCache {
    class Key: NSObject {
        let imageConfiguration: ImageConfiguration
        
        init(imageConfiguration: ImageConfiguration) {
            self.imageConfiguration = imageConfiguration
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? Key else {
                return false
            }
            
            let lhs = self
            return lhs.imageConfiguration == rhs.imageConfiguration
        }
        
        override var hash: Int {
            return imageConfiguration.hashValue
        }
    }
    
    static var shared = NSCache<Key, UIImage>()
}

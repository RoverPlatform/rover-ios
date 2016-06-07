//
//  AssetManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-30.
//
//

import Foundation

class AssetManager {
    
    static let sharedManager = AssetManager()
    
    let cache = AssetCache()
    let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

    func fetchAsset(url url: NSURL, completion: (NSData? -> Void)) {
        let key = cacheKey(url: url)
        
        if let data = cache.inMemoryCachedData(key: key) {
            dispatch_async(dispatch_get_main_queue()) {
                rvLog("Asset found in memory cache", data: url.path, level: .Trace)
                completion(data)
            }
            return
        }
        
        let dataTask = session.dataTaskWithURL(url) { (data, response, error) in
            if error != nil {
                rvLog("Could not download asset", data: url, level: .Error)
            } else if let data = data {
                self.cache.setAsset(data: data, key: key)
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(data)
            }
        }
        
        cache.queryDiskCache(key: key) { (data, error) in
            if let data = data {
                rvLog("Asset found on disk cache", data: url.path, level: .Trace)
                completion(data)
                return
            }
            
            dataTask.resume()
        }
    }
    
    func hasCacheForAsset(url url: NSURL) -> Bool {
        return cache.hasInMemoryCache(key: cacheKey(url: url))
    }
    
    func cacheAsset(data data: NSData, url: NSURL) {
        cache.setAsset(data: data, key: cacheKey(url: url))
    }
    
    func clearCache() {
        cache.clearCache()
    }
    
    // MARK: Helpers
    
    func cacheKey(url url: NSURL) -> String {
        return url.lastPathComponent ?? url.absoluteString
    }
}
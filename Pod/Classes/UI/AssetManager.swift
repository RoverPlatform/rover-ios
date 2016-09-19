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
    let session = URLSession(configuration: URLSessionConfiguration.default)

    func fetchAsset(url: URL, completion: @escaping ((Data?) -> Void)) {
        let key = cacheKey(url: url)
        
        if let data = cache.inMemoryCachedData(key: key) {
            DispatchQueue.main.async {
                //rvLog("Asset found in memory cache", data: url.path, level: .Trace)
                completion(data as Data)
            }
            return
        }
        
        let dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if error != nil {
                rvLog("Could not download asset", data: url, level: .error)
            } else if let data = data {
                self.cache.setAsset(data: data, key: key)
            }
            
            DispatchQueue.main.async {
                completion(data)
            }
        }) 
        
        cache.queryDiskCache(key: key) { (data, error) in
            if let data = data {
                //rvLog("Asset found on disk cache", data: url.path, level: .Trace)
                completion(data)
                return
            }
            
            dataTask.resume()
        }
    }
    
    func hasCacheForAsset(url: URL) -> Bool {
        return cache.hasInMemoryCache(key: cacheKey(url: url))
    }
    
    func cacheAsset(data: Data, url: URL) {
        cache.setAsset(data: data, key: cacheKey(url: url))
    }
    
    func clearCache() {
        cache.clearCache()
    }
    
    // MARK: Helpers
    
    func cacheKey(url: URL) -> String {
        return url.absoluteString.addingPercentEscapes(using: String.Encoding.utf8) ?? url.absoluteString
    }
}

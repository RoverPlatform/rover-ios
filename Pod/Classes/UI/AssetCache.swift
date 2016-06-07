//
//  AssetCache.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-30.
//
//

import Foundation

class AssetCache {
    
    let memCache = NSCache()
    let ioQueue = dispatch_queue_create("io.rover.AssetCache", DISPATCH_QUEUE_SERIAL)
    let diskCachePath = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0].stringByAppendingPathComponent("RoverAssetCache")
    
    var fileManager: NSFileManager?
    
    init() {
        memCache.name = "io.rover.AssetCache"
        
        dispatch_async(ioQueue) { 
            self.fileManager = NSFileManager()
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AssetCache.clearInMemoryCache), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func clearInMemoryCache() {
        memCache.removeAllObjects()
    }
    
    func clearDiskCache() {
        dispatch_async(ioQueue) { 
            do {
                try self.fileManager?.removeItemAtPath(self.diskCachePath)
                try self.fileManager?.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                rvLog("Could not clear disk cache directory", data: error, level: .Error)
            }
        }
    }
    
    func hasInMemoryCache(key key: String) -> Bool {
        if memCache.objectForKey(key) != nil {
            return true
        }
        return false
    }
    
    func setAsset(data data: NSData, key: String) {
        // Store in memory
        memCache.setObject(data, forKey: key, cost: data.length)
        
        // Store on disk
        dispatch_async(ioQueue) { 
            if !self.fileManager!.fileExistsAtPath(self.diskCachePath) {
                do {
                    try self.fileManager?.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    rvLog("Could not create cache directory", data: error, level: .Error)
                    return
                }
            }
            
            let filePath = self.filePathForAsset(key: key)
            self.fileManager?.createFileAtPath(filePath, contents: data, attributes: nil)
            
            // Disable iCloud backup
            let fileURL: NSURL = NSURL(fileURLWithPath: filePath)
            do {
                try fileURL.setResourceValue(false, forKey: NSURLIsExcludedFromBackupKey)
            } catch {
                rvLog("Cold not disable iCloud backup on cached asset", data: key, level: .Error)
            }
        }
    }
    
    func filePathForAsset(key key: String) -> String {
        return diskCachePath.stringByAppendingPathComponent(key)
    }
    
    func clearCache() {
        clearInMemoryCache()
        clearDiskCache()
    }
    
    func queryDiskCache(key key: String, completion: (NSData?, ErrorType?) -> Void) {
        let filePath = filePathForAsset(key: key)
        
        dispatch_async(ioQueue) {
            if !self.fileManager!.fileExistsAtPath(filePath) {
                let error = NSError(domain: "io.rover.AssetCache", code: Int(ENOENT), userInfo: nil)
                dispatch_async(dispatch_get_main_queue()) {
                    completion(nil, error)
                }
                return
            }
            
            if let data = NSData(contentsOfFile: filePath) {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(data, nil)
                }
            }
        }
    }
    
    func inMemoryCachedData(key key: String) -> NSData? {
        if let data = memCache.objectForKey(key) as? NSData {
            return data
        }
        return nil
    }
}

extension String {
    
    func stringByAppendingPathComponent(path: String) -> String {
        
        let nsSt = self as NSString
        
        return nsSt.stringByAppendingPathComponent(path)
    }
}
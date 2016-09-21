//
//  AssetCache.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-30.
//
//

import Foundation

class AssetCache {
    
    let memCache = NSCache<NSString, NSData>()
    let ioQueue = DispatchQueue(label: "io.rover.AssetCache", attributes: [])
    let diskCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0].stringByAppendingPathComponent("RoverAssetCache")
    
    var fileManager: FileManager?
    
    init() {
        memCache.name = "io.rover.AssetCache"
        
        ioQueue.async { 
            self.fileManager = FileManager()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(AssetCache.clearInMemoryCache), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func clearInMemoryCache() {
        memCache.removeAllObjects()
    }
    
    func clearDiskCache() {
        ioQueue.async { 
            do {
                try self.fileManager?.removeItem(atPath: self.diskCachePath)
                try self.fileManager?.createDirectory(atPath: self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                rvLog("Could not clear disk cache directory", data: error, level: .error)
            }
        }
    }
    
    func hasInMemoryCache(key: String) -> Bool {
        if memCache.object(forKey: key as! NSString) != nil {
            return true
        }
        return false
    }
    
    func setAsset(data: Data, key: String) {
        // Store in memory
        memCache.setObject(data as! NSData, forKey: key as! NSString, cost: data.count)
        
        // Store on disk
        ioQueue.async { 
            if !self.fileManager!.fileExists(atPath: self.diskCachePath) {
                do {
                    try self.fileManager?.createDirectory(atPath: self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    rvLog("Could not create cache directory", data: error, level: .error)
                    return
                }
            }
            
            let filePath = self.filePathForAsset(key: key)
            self.fileManager?.createFile(atPath: filePath, contents: data, attributes: nil)
            
            // Disable iCloud backup
            var fileURL: URL = URL(fileURLWithPath: filePath)
            fileURL.setTemporaryResourceValue(false, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
    }
    
    func filePathForAsset(key: String) -> String {
        return diskCachePath.stringByAppendingPathComponent(key)
    }
    
    func clearCache() {
        clearInMemoryCache()
        clearDiskCache()
    }
    
    func queryDiskCache(key: String, completion: @escaping (Data?, Error?) -> Void) {
        let filePath = filePathForAsset(key: key)
        
        ioQueue.async {
            if !self.fileManager!.fileExists(atPath: filePath) {
                let error = NSError(domain: "io.rover.AssetCache", code: Int(ENOENT), userInfo: nil)
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                DispatchQueue.main.async {
                    completion(data, nil)
                }
            }
        }
    }
    
    func inMemoryCachedData(key: String) -> Data? {
        if let data = memCache.object(forKey: key as! NSString) as? Data {
            return data
        }
        return nil
    }
}

extension String {
    
    func stringByAppendingPathComponent(_ path: String) -> String {
        
        let nsSt = self as NSString
        
        return nsSt.appendingPathComponent(path)
    }
}

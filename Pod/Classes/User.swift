//
//  User.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation

public class User : NSObject, NSCoding {
    
    var name: String? { didSet { cacheToDisk() } }
    var email: String? { didSet { cacheToDisk() } }
    var phone: String? { didSet { cacheToDisk() } }
    var alias: String? { didSet { cacheToDisk() } }
    var tags: [String]? { didSet { cacheToDisk() } }
    
    // TODO: traits
    
    private static var _sharedUser: User?
    static var sharedUser: User {
        guard _sharedUser == nil else { return _sharedUser! }
        
        if let data = NSUserDefaults.standardUserDefaults().objectForKey("ROVER_SHARED_USER") as? NSData, _user = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? User {
            _sharedUser = _user
            return _sharedUser!
        } else {
            _sharedUser = User()
            return _sharedUser!
        }
    }
    
    private func cacheToDisk() {
        let data = NSKeyedArchiver.archivedDataWithRootObject(self)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: "ROVER_SHARED_USER")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    // MARK: NSCoding
    
    required convenience public init?(coder aDecoder: NSCoder) {
        self.init()
        name = aDecoder.decodeObjectForKey("name") as? String
        email = aDecoder.decodeObjectForKey("email") as? String
        phone = aDecoder.decodeObjectForKey("phone") as? String
        alias = aDecoder.decodeObjectForKey("alias") as? String
        tags = aDecoder.decodeObjectForKey("tags") as? [String]
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(email, forKey: "email")
        aCoder.encodeObject(phone, forKey: "phone")
        aCoder.encodeObject(alias, forKey: "alias")
        aCoder.encodeObject(tags, forKey: "tags")
    }
    
}
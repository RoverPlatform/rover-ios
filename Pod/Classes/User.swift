//
//  User.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation

public class User : NSObject, NSCoding {
    
    public var identifier: String?
    public var name: String?
    public var email: String?
    public var phone: String?
    public var tags: [String]?
    public var gender: String?
    public var age: Int?
    public var traits: [String: AnyObject]
    
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
    
    override init() {
        traits = [String: AnyObject]()
        
        super.init()
    }
    
    public func save() {
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
        identifier = aDecoder.decodeObjectForKey("identifier") as? String
        tags = aDecoder.decodeObjectForKey("tags") as? [String]
        gender = aDecoder.decodeObjectForKey("gender") as? String
        age = aDecoder.decodeObjectForKey("age") as? Int
        if let traits = aDecoder.decodeObjectForKey("traits") as? [String: AnyObject] {
            self.traits = traits
        }
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(email, forKey: "email")
        aCoder.encodeObject(phone, forKey: "phone")
        aCoder.encodeObject(identifier, forKey: "identifier")
        aCoder.encodeObject(tags, forKey: "tags")
        aCoder.encodeObject(traits, forKey: "traits")
        aCoder.encodeObject(gender, forKey: "gender")
        aCoder.encodeObject(age, forKey: "age")
    }
    
}
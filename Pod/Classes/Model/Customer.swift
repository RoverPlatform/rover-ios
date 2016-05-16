//
//  User.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation

public class Customer : NSObject, NSCoding {
    
    public var identifier: String?
    public var firstName: String?
    public var lastName: String?
    public var email: String?
    public var phone: String?
    public var tags: [String]?
    public var gender: String?
    public var age: Int?
    public var traits: [String: AnyObject]
    
    private static var _sharedCustomer: Customer?
    static var sharedCustomer: Customer {
        guard _sharedCustomer == nil else { return _sharedCustomer! }
        
        if let data = NSUserDefaults.standardUserDefaults().objectForKey("ROVER_SHARED_CUSTOMER") as? NSData, _customer = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? Customer {
            _sharedCustomer = _customer
            return _sharedCustomer!
        } else {
            _sharedCustomer = Customer()
            return _sharedCustomer!
        }
    }
    
    override init() {
        traits = [String: AnyObject]()
        
        super.init()
    }
    
    public func save() {
        let data = NSKeyedArchiver.archivedDataWithRootObject(self)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: "ROVER_SHARED_CUSTOMER")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    // MARK: NSCoding
    
    required convenience public init?(coder aDecoder: NSCoder) {
        self.init()
        firstName = aDecoder.decodeObjectForKey("firstName") as? String
        lastName = aDecoder.decodeObjectForKey("lastName") as? String
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
        aCoder.encodeObject(firstName, forKey: "firstname")
        aCoder.encodeObject(lastName, forKey: "lastName")
        aCoder.encodeObject(email, forKey: "email")
        aCoder.encodeObject(phone, forKey: "phone")
        aCoder.encodeObject(identifier, forKey: "identifier")
        aCoder.encodeObject(tags, forKey: "tags")
        aCoder.encodeObject(traits, forKey: "traits")
        aCoder.encodeObject(gender, forKey: "gender")
        aCoder.encodeObject(age, forKey: "age")
    }
    
}
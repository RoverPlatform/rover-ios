//
//  User.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation

open class Customer : NSObject, NSCoding {
    
    open var identifier: String?
    open var firstName: String?
    open var lastName: String?
    open var email: String?
    open var phone: String?
    open var tags: [String]?
    open var gender: String?
    open var age: Int?
    open var traits: [String: Any]
    
    fileprivate static var _sharedCustomer: Customer?
    static var sharedCustomer: Customer {
        guard _sharedCustomer == nil else { return _sharedCustomer! }
        
        if let data = UserDefaults.standard.object(forKey: "ROVER_SHARED_CUSTOMER") as? Data, let _customer = NSKeyedUnarchiver.unarchiveObject(with: data) as? Customer {
            _sharedCustomer = _customer
            return _sharedCustomer!
        } else {
            _sharedCustomer = Customer()
            return _sharedCustomer!
        }
    }
    
    override init() {
        traits = [String: Any]()
        
        super.init()
    }
    
    open func save() {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(data, forKey: "ROVER_SHARED_CUSTOMER")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: NSCoding
    
    required convenience public init?(coder aDecoder: NSCoder) {
        self.init()
        firstName = aDecoder.decodeObject(forKey: "firstName") as? String
        lastName = aDecoder.decodeObject(forKey: "lastName") as? String
        email = aDecoder.decodeObject(forKey: "email") as? String
        phone = aDecoder.decodeObject(forKey: "phone") as? String
        identifier = aDecoder.decodeObject(forKey: "identifier") as? String
        tags = aDecoder.decodeObject(forKey: "tags") as? [String]
        gender = aDecoder.decodeObject(forKey: "gender") as? String
        age = aDecoder.decodeObject(forKey: "age") as? Int
        if let traits = aDecoder.decodeObject(forKey: "traits") as? [String: Any] {
            self.traits = traits
        }
    }
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encode(firstName, forKey: "firstname")
        aCoder.encode(lastName, forKey: "lastName")
        aCoder.encode(email, forKey: "email")
        aCoder.encode(phone, forKey: "phone")
        aCoder.encode(identifier, forKey: "identifier")
        aCoder.encode(tags, forKey: "tags")
        aCoder.encode(traits, forKey: "traits")
        aCoder.encode(gender, forKey: "gender")
        aCoder.encode(age, forKey: "age")
    }
    
}

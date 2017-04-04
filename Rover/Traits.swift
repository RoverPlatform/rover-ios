//
//  Traits.swift
//  Rover
//
//  Created by Sean Rucker on 2016-12-05.
//  Copyright © 2016 Sean Rucker. All rights reserved.
//

import Foundation

public final class Traits: NSObject {
    
    static let identifierKey = "identifier"
    static let firstNameKey = "first-name"
    static let lastNameKey = "last-name"
    static let genderKey = "gender"
    static let ageKey = "age"
    static let emailKey = "email"
    static let phoneNumberKey = "phone-number"
    static let tagsKey = "tags"
    static let tagsToAddKey = "tagsToAdd"
    static let tagsToRemoveKey = "tagsToRemove"
    
    static let supportedKeys = Set(arrayLiteral: Traits.identifierKey, Traits.firstNameKey, Traits.lastNameKey, Traits.genderKey, Traits.ageKey, Traits.emailKey, Traits.phoneNumberKey, Traits.tagsKey, Traits.tagsToAddKey, Traits.tagsToRemoveKey)
    
    public enum Gender: String {
        case male, female
    }
    
    var valueMap = [String: Any]()
    
    var identifier: Any? {
        return valueMap[Traits.identifierKey]
    }
    
    var firstName: Any? {
        return valueMap[Traits.firstNameKey]
    }
    
    var lastName: Any? {
        return valueMap[Traits.lastNameKey]
    }
    
    var email: Any? {
        return valueMap[Traits.emailKey]
    }
    
    var phoneNumber: Any? {
        return valueMap[Traits.phoneNumberKey]
    }
    
    var gender: Any? {
        return valueMap[Traits.genderKey]
    }
    
    var age: Any? {
        return valueMap[Traits.ageKey]
    }
    
    var tags: [String]? {
        return valueMap[Traits.tagsKey] as? [String]
    }
    
    var tagsToAdd: [String]? {
        return valueMap[Traits.tagsToAddKey] as? [String]
    }
    
    var tagsToRemove: [String]? {
        return valueMap[Traits.tagsToRemoveKey] as? [String]
    }
    
    var customValues: [String: Any]? {
        let customValues = self.valueMap.filter { !Traits.supportedKeys.contains($0.0) }
        
        guard !customValues.isEmpty else {
            return nil
        }
        
        var valueMap = [String: Any]()
        
        for (key, value) in customValues {
            valueMap[key] = value
        }
        
        return valueMap
    }
    
    public func set(identifier: String) {
        valueMap[Traits.identifierKey] = identifier
    }
    
    public func removeIdentifier() {
        valueMap[Traits.identifierKey] = NSNull()
    }
    
    public func set(firstName: String) {
        valueMap[Traits.firstNameKey] = firstName
    }
    
    public func removeFirstName() {
        valueMap[Traits.firstNameKey] = NSNull()
    }
    
    public func set(lastName: String) {
        valueMap[Traits.lastNameKey] = lastName
    }
    
    public func removeLastName() {
        valueMap[Traits.lastNameKey] = NSNull()
    }
    
    public func set(email: String) {
        valueMap[Traits.emailKey] = email
    }
    
    public func removeEmail() {
        valueMap[Traits.emailKey] = NSNull()
    }
    
    public func set(phoneNumber: String) {
        valueMap[Traits.phoneNumberKey] = phoneNumber
    }
    
    public func removePhoneNumber() {
        valueMap[Traits.phoneNumberKey] = NSNull()
    }
    
    public func set(gender: Gender) {
        valueMap[Traits.genderKey] = gender.rawValue
    }
    
    public func removeGender() {
        valueMap[Traits.genderKey] = NSNull()
    }
    
    public func set(age: Int) {
        valueMap[Traits.ageKey] = age
    }
    
    public func removeAge() {
        valueMap[Traits.ageKey] = NSNull()
    }
    
    public func set(tags: [String]) {
        valueMap[Traits.tagsKey] = tags
    }
    
    public func add(tag: String) {
        var tags = valueMap[Traits.tagsToAddKey] as? [String] ?? [String]()
        tags.append(tag)
        valueMap[Traits.tagsToAddKey] = tags
    }
    
    public func remove(tag: String) {
        var tags = valueMap[Traits.tagsToRemoveKey] as? [String] ?? [String]()
        tags.append(tag)
        valueMap[Traits.tagsToRemoveKey] = tags
    }
    
    public func set(customValue: Any, forKey key: String) {
        valueMap[key] = customValue
    }
    
    public func removeCustomValue(forKey key: String) {
        valueMap[key] = NSNull()
    }
}

extension Traits {
    
    override public var description: String {
        return String(describing: valueMap)
    }
}

extension Traits: ExpressibleByDictionaryLiteral {
    
    public typealias Key = String
    public typealias Value = Any
    
    public convenience init(dictionaryLiteral elements: (Traits.Key, Traits.Value)...) {
        for (key, value) in elements {
            switch key {
            case Traits.identifierKey, Traits.firstNameKey, Traits.lastNameKey, Traits.emailKey, Traits.phoneNumberKey:
                valueMap[key] = value as? String
            case Traits.genderKey:
                if let string = value as? String, let gender = Gender(rawValue: string) {
                    valueMap[key] = gender.rawValue
                }
            case Traits.ageKey:
                valueMap[key] = value as? Int
            case Traits.tagsKey, Traits.tagsToAddKey, Traits.tagsToRemoveKey:
                valueMap[key] = value as? [String]
            default:
                valueMap[key] = value
            }
        }
    }
}

extension Traits: Sequence {
    
    public typealias Iterator = DictionaryIterator<String, Any>
    
    public func makeIterator() -> Iterator {
        return valueMap.makeIterator()
    }
}

extension Traits: Collection {
    
    public typealias Index = DictionaryIndex<String, Any>
    
    public var startIndex: Index {
        return valueMap.startIndex
    }
    
    public var endIndex: Index {
        return valueMap.endIndex
    }
    
    public subscript (position: Index) -> Iterator.Element {
        return valueMap[position]
    }
    
    public func index(after i: Index) -> Index {
        return valueMap.index(after: i)
    }
}

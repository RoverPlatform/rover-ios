//
//  TraitsTests.swift
//  RoverTests
//
//  Created by Sean Rucker on 2016-12-05.
//  Copyright © 2016 Sean Rucker. All rights reserved.
//

import XCTest
@testable import Rover

class TraitsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValueMap() {
        var traits = Traits()
        traits.set(identifier: "marieavgeropoulos")
        traits.set(firstName: "Marie")
        traits.set(lastName: "Avgeropoulos")
        traits.set(email: "marie.avgeropoulos@example.com")
        traits.set(gender: .female)
        traits.set(age: 30)
        traits.set(phoneNumber: "555-555-5555")
        traits.set(tags: ["actress", "model", "musician"])
        
        XCTAssertEqual(traits.identifier as? String, "marieavgeropoulos")
        XCTAssertEqual(traits.firstName as? String, "Marie")
        XCTAssertEqual(traits.lastName as? String, "Avgeropoulos")
        XCTAssertEqual(traits.gender as? String, Traits.Gender.female.rawValue)
        XCTAssertEqual(traits.age as? Int, 30)
        XCTAssertEqual(traits.email as? String, "marie.avgeropoulos@example.com")
        XCTAssertEqual(traits.phoneNumber as? String, "555-555-5555")
        XCTAssertEqual(traits.tags!, ["actress", "model", "musician"])
    }
    
    func testAddRemoveTags() {
        var traits = Traits()
        traits.add(tag: "actress")
        XCTAssertEqual(traits.tagsToAdd!, ["actress"])
        
        traits.add(tag: "model")
        XCTAssertEqual(traits.tagsToAdd!, ["actress", "model"])
        
        traits.remove(tag: "musician")
        XCTAssertEqual(traits.tagsToRemove!, ["musician"])
    }
    
    func testNullValues() {
        var traits = Traits()

        traits.removeIdentifier()
        traits.removeFirstName()
        traits.removeLastName()
        traits.removeEmail()
        traits.removeGender()
        traits.removeAge()
        traits.removePhoneNumber()
        
        XCTAssert(traits.identifier is NSNull)
        XCTAssert(traits.firstName is NSNull)
        XCTAssert(traits.lastName is NSNull)
        XCTAssert(traits.email is NSNull)
        XCTAssert(traits.gender is NSNull)
        XCTAssert(traits.age is NSNull)
        XCTAssert(traits.phoneNumber is NSNull)
    }
    
    func testNilValues() {
        let traits = Traits()

        XCTAssertNil(traits.identifier)
        XCTAssertNil(traits.firstName)
        XCTAssertNil(traits.lastName)
        XCTAssertNil(traits.gender)
        XCTAssertNil(traits.age)
        XCTAssertNil(traits.email)
        XCTAssertNil(traits.phoneNumber)
    }
    
    func testCustomValues() {
        var traits = Traits()
        traits.set(customValue: "bar", forKey: "foo")
        
        XCTAssertEqual(traits.valueMap["foo"] as? String, "bar")
        XCTAssertEqual(traits.valueMap.count, 1)
        
        traits.set(identifier: "marieavgeropoulos")
        
        XCTAssertEqual(traits.valueMap.count, 2)
        XCTAssertEqual(traits.customValues?.count, 1)
        XCTAssertEqual(traits.customValues?["foo"] as? String, "bar")
    }
    
    func testInitializeByDictionary() {
        let traits: Traits = [
            Traits.identifierKey: "marieavgeropoulos",
            Traits.tagsKey: ["actress"],
            "foo": "bar"
        ]
        
        XCTAssertEqual(traits.valueMap.count, 3)
        XCTAssertEqual(traits.identifier as? String, "marieavgeropoulos")
        XCTAssertEqual(traits.customValues?.count, 1)
        XCTAssertEqual(traits.customValues?["foo"] as? String, "bar")
    }
    
    func testInvalidDictionary() {
        let traits: Traits = [
            Traits.identifierKey: 80000516109,
            Traits.firstNameKey: 999,
            Traits.lastNameKey: 999,
            Traits.emailKey: 999,
            Traits.genderKey: "unidentified",
            Traits.ageKey: "1",
            Traits.phoneNumberKey: 5555555555,
            Traits.tagsKey: "empty"
        ]
        
        XCTAssertNil(traits.identifier)
        XCTAssertNil(traits.firstName)
        XCTAssertNil(traits.lastName)
        XCTAssertNil(traits.gender)
        XCTAssertNil(traits.age)
        XCTAssertNil(traits.email)
        XCTAssertNil(traits.phoneNumber)
        XCTAssertNil(traits.tags)
    }
}

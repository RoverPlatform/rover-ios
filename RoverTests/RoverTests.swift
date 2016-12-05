//
//  RoverTests.swift
//  Rover
//
//  Created by Sean Rucker on 2016-12-05.
//  Copyright © 2016 Sean Rucker. All rights reserved.
//

import XCTest
@testable import Rover

class RoverTests: XCTestCase {
    
    func identifyAsMarie() {
        var traits = Traits()
        traits.set(identifier: "marieavgeropoulos")
        traits.set(firstName: "Marie")
        traits.set(lastName: "Avgeropoulos")
        traits.set(email: "marie.avgeropoulos@example.com")
        traits.set(gender: .female)
        traits.set(age: 30)
        traits.set(phoneNumber: "555-555-5555")
        traits.set(tags: ["actress", "model"])
        
        Rover.identify(traits: traits)
    }
    
    func testIdentify() {
        let customer = Rover.customer

        // Can't test for nil because its impossible to reset NSUserDefaults with the
        // current implementation.
        // http://stackoverflow.com/questions/19084633/shouldnt-nsuserdefault-be-clean-slate-for-unit-tests
        
//        XCTAssertNil(customer.identifier)
//        XCTAssertNil(customer.firstName)
//        XCTAssertNil(customer.lastName)
//        XCTAssertNil(customer.email)
//        XCTAssertNil(customer.gender)
//        XCTAssertNil(customer.age)
//        XCTAssertNil(customer.phone)
//        XCTAssertNil(customer.tags)
        
        identifyAsMarie()
        
        XCTAssertEqual(customer.identifier, "marieavgeropoulos")
        XCTAssertEqual(customer.firstName, "Marie")
        XCTAssertEqual(customer.lastName, "Avgeropoulos")
        XCTAssertEqual(customer.gender, Traits.Gender.female.rawValue)
        XCTAssertEqual(customer.age, 30)
        XCTAssertEqual(customer.email, "marie.avgeropoulos@example.com")
        XCTAssertEqual(customer.phone, "555-555-5555")
        XCTAssertEqual(customer.tags!, ["actress", "model"])

        var traits = Traits()
        traits.add(tag: "musician")
        traits.remove(tag: "actress")
        
        Rover.identify(traits: traits)
        XCTAssertEqual(customer.tags!, ["model", "musician"])
        
        traits = Traits()
        traits.set(customValue: "bar", forKey: "foo")
        
        Rover.identify(traits: traits)
        XCTAssertEqual(customer.traits["foo"] as? String, "bar")
    }
    
    func testClearCustomer() {
        identifyAsMarie()
        
        Rover.clearCustomer()
        
        let customer = Rover.customer
        
        XCTAssertNil(customer.identifier)
        XCTAssertNil(customer.firstName)
        XCTAssertNil(customer.lastName)
        XCTAssertNil(customer.email)
        XCTAssertNil(customer.gender)
        XCTAssertNil(customer.age)
        XCTAssertNil(customer.phone)
        XCTAssertNil(customer.tags)
    }
}

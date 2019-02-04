//
//  RoverFoundationTests.swift
//  RoverFoundationTests
//
//  Created by Sean Rucker on 2018-02-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

@testable import RoverFoundation
import XCTest

class MockService {
    var arg1: String?
    var arg2: Int?
    var arg3: Bool?
    
    init(arg1: String? = nil, arg2: Int? = nil, arg3: Bool? = nil) {
        self.arg1 = arg1
        self.arg2 = arg2
        self.arg3 = arg3
    }
}

class RoverFoundationTests: XCTestCase {
    func testRegisterWithoutNameWithoutScopeAndZeroArgs() {
        let rover = Rover()
        rover.register(MockService.self) { _ in MockService(arg1: "foo") }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1?.arg1, "foo")
        
        let result2 = rover.resolve(MockService.self)
        XCTAssert(result2 === result1)
    }
    
    func testRegisterWithNameWithoutScopeAndZeroArgs() {
        let rover = Rover()
        rover.register(MockService.self, name: "bar") { _ in MockService(arg1: "foo") }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, name: "baz")
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, name: "bar")
        XCTAssertNotNil(result3)
        XCTAssertEqual(result3?.arg1, "foo")
        
        let result4 = rover.resolve(MockService.self, name: "bar")
        XCTAssert(result4 === result3)
    }
    
    func testRegisterWithoutNameTransientScopeAndZeroArgs() {
        let rover = Rover()
        rover.register(MockService.self, scope: .transient) { _ in MockService(arg1: "foo") }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1?.arg1, "foo")
        
        let result2 = rover.resolve(MockService.self)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result2?.arg1, "foo")
        XCTAssert(result2 !== result1)
    }
    
    func testRegisterWithNameTransientScopeAndZeroArgs() {
        let rover = Rover()
        rover.register(MockService.self, name: "bar", scope: .transient) { _ in MockService(arg1: "foo") }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, name: "baz")
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, name: "bar")
        XCTAssertNotNil(result3)
        XCTAssertEqual(result3?.arg1, "foo")
        
        let result4 = rover.resolve(MockService.self, name: "bar")
        XCTAssertNotNil(result4)
        XCTAssertEqual(result4?.arg1, "foo")
        XCTAssert(result4 !== result3)
    }
    
    func testRegisterWithoutNameWithoutScopeAndOneArg() {
        let rover = Rover()
        rover.register(MockService.self) { (_, arg1: String) in MockService(arg1: arg1) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNotNil(result4)
        XCTAssertEqual(result4?.arg1, "foo")
        
        let result5 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssert(result5 === result4)
    }
    
    func testRegisterWithNameWithoutScopeAndOneArg() {
        let rover = Rover()
        rover.register(MockService.self, name: "bar") { (_, arg1: String) in MockService(arg1: arg1) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNil(result4)
        
        let result5 = rover.resolve(MockService.self, name: "bar", arguments: 1)
        XCTAssertNil(result5)
        
        let result6 = rover.resolve(MockService.self, name: "bar", arguments: true)
        XCTAssertNil(result6)
        
        let result7 = rover.resolve(MockService.self, name: "bar", arguments: "foo")
        XCTAssertNotNil(result7)
        XCTAssertEqual(result7?.arg1, "foo")
        
        let result8 = rover.resolve(MockService.self, name: "bar", arguments: "foo")
        XCTAssert(result8 === result7)
    }
    
    func testRegisterWithoutNameTransientScopeAndOneArg() {
        let rover = Rover()
        rover.register(MockService.self, scope: .transient) { (_, arg1: String) in MockService(arg1: arg1) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNotNil(result4)
        XCTAssertEqual(result4?.arg1, "foo")
        
        let result5 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNotNil(result5)
        XCTAssertEqual(result5?.arg1, "foo")
        XCTAssert(result5 !== result4)
    }
    
    func testRegisterWithNameTransientScopeAndOneArg() {
        let rover = Rover()
        rover.register(MockService.self, name: "bar", scope: .transient) { (_, arg1: String) in MockService(arg1: arg1) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNil(result4)
        
        let result5 = rover.resolve(MockService.self, name: "bar", arguments: 1)
        XCTAssertNil(result5)
        
        let result6 = rover.resolve(MockService.self, name: "bar", arguments: true)
        XCTAssertNil(result6)
        
        let result7 = rover.resolve(MockService.self, name: "bar", arguments: "foo")
        XCTAssertNotNil(result7)
        XCTAssertEqual(result7?.arg1, "foo")
        
        let result8 = rover.resolve(MockService.self, name: "bar", arguments: "foo")
        XCTAssertNotNil(result8)
        XCTAssertEqual(result8?.arg1, "foo")
        XCTAssert(result8 !== result7)
    }
    
    func testRegisterWithoutNameWithoutScopeAndTwoArgs() {
        let rover = Rover()
        rover.register(MockService.self) { (_, arg1: String, arg2: Int) in MockService(arg1: arg1, arg2: arg2) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNil(result4)
        
        let result5 = rover.resolve(MockService.self, arguments: "foo", "bar")
        XCTAssertNil(result5)
        
        let result6 = rover.resolve(MockService.self, arguments: "foo", true)
        XCTAssertNil(result6)
        
        let result7 = rover.resolve(MockService.self, arguments: "foo", 1)
        XCTAssertNotNil(result7)
        XCTAssertEqual(result7?.arg1, "foo")
        XCTAssertEqual(result7?.arg2, 1)
        
        let result8 = rover.resolve(MockService.self, arguments: "foo", 1)
        XCTAssert(result8 === result7)
    }
    
    func testRegisterWithNameWithoutScopeAndTwoArgs() {
        let rover = Rover()
        rover.register(MockService.self, name: "bar") { (_, arg1: String, arg2: Int) in MockService(arg1: arg1, arg2: arg2) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNil(result4)
        
        let result5 = rover.resolve(MockService.self, arguments: "foo", "bar")
        XCTAssertNil(result5)
        
        let result6 = rover.resolve(MockService.self, arguments: "foo", true)
        XCTAssertNil(result6)
        
        let result7 = rover.resolve(MockService.self, arguments: "foo", 1)
        XCTAssertNil(result7)
        
        let result8 = rover.resolve(MockService.self, name: "bar")
        XCTAssertNil(result8)
        
        let result9 = rover.resolve(MockService.self, name: "bar", arguments: 1)
        XCTAssertNil(result9)
        
        let result10 = rover.resolve(MockService.self, name: "bar", arguments: true)
        XCTAssertNil(result10)
        
        let result11 = rover.resolve(MockService.self, name: "bar", arguments: "foo")
        XCTAssertNil(result11)
        
        let result12 = rover.resolve(MockService.self, name: "bar", arguments: "foo", "bar")
        XCTAssertNil(result12)
        
        let result13 = rover.resolve(MockService.self, name: "bar", arguments: "foo", true)
        XCTAssertNil(result13)
        
        let result14 = rover.resolve(MockService.self, name: "bar", arguments: "foo", 1)
        XCTAssertNotNil(result14)
        XCTAssertEqual(result14?.arg1, "foo")
        XCTAssertEqual(result14?.arg2, 1)
        
        let result15 = rover.resolve(MockService.self, name: "bar", arguments: "foo", 1)
        XCTAssert(result15 === result14)
    }
    
    func testRegisterWithoutNameTransientScopeAndTwoArgs() {
        let rover = Rover()
        rover.register(MockService.self, scope: .transient) { (_, arg1: String, arg2: Int) in MockService(arg1: arg1, arg2: arg2) }
        
        let result1 = rover.resolve(MockService.self)
        XCTAssertNil(result1)
        
        let result2 = rover.resolve(MockService.self, arguments: 1)
        XCTAssertNil(result2)
        
        let result3 = rover.resolve(MockService.self, arguments: true)
        XCTAssertNil(result3)
        
        let result4 = rover.resolve(MockService.self, arguments: "foo")
        XCTAssertNil(result4)
        
        let result5 = rover.resolve(MockService.self, arguments: "foo", "bar")
        XCTAssertNil(result5)
        
        let result6 = rover.resolve(MockService.self, arguments: "foo", true)
        XCTAssertNil(result6)
        
        let result7 = rover.resolve(MockService.self, arguments: "foo", 1)
        XCTAssertNotNil(result7)
        XCTAssertEqual(result7?.arg1, "foo")
        XCTAssertEqual(result7?.arg2, 1)
        
        let result8 = rover.resolve(MockService.self, arguments: "foo", 1)
        XCTAssertNotNil(result8)
        XCTAssertEqual(result8?.arg1, "foo")
        XCTAssertEqual(result8?.arg2, 1)
        XCTAssert(result8 !== result7)
    }
}

//
//  AttributesTests.swift
//  RoverDataTests
//
//  Created by Andrew Clunis on 2018-12-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverData

class AttributesTests: XCTestCase {
    
    let exampleAttributes: [String: Any] = [
        "testInt": 42,
        "anArray": [1, 2, 3, 4],
        "testTrueBoolean": true,
        "testString": "donut",
        "testFalseBoolean": false,
        "nestedObject": ["anArray": [1, 2, 3, 4]]
    ]

    func testAttributesCoercion() {
        let dictionary = ["thing": 42]
        let attributes = dictionary.attributes
    }

    func testCodableRoundtrip() {
        
    }
    
    func testNsCodingRoundtrip() {
        
    }
    
}

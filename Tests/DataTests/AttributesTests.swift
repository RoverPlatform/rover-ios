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
    
    func verifyDecodedAttributes(attributes: Attributes) {
        XCTAssertEqual(attributes.rawValue["testInt"] as! Int, 42)
        XCTAssertEqual(attributes.rawValue["anArray"] as! [Int], [1, 2, 3, 4])
        XCTAssertEqual(attributes.rawValue["testTrueBoolean"] as! Bool, true)
        XCTAssertEqual(attributes.rawValue["testString"] as! String, "donut")
        XCTAssertEqual(attributes.rawValue["testFalseBoolean"] as! Bool, false)
        XCTAssertEqual((attributes.rawValue["nestedObject"] as! [String: Any])["anArray"] as! [Int], [1, 2, 3, 4])
    }

    func testCodableRoundtrip() throws {
        // use JSONEncoder to test that Codable was synthesized properly.
        let json = try JSONEncoder.default.encode(Attributes.init(rawValue: exampleAttributes))
        
        do {
            let attributes = try JSONDecoder.default.decode(Attributes.self, from: json)
            
            verifyDecodedAttributes(attributes: attributes)
        } catch {
            // Print the error so the all-important UserInfo is captured:
            print("Error decoding device: \(error)")
            throw error
        }
    }
    
    func testNSCodingRoundtrip() throws {
        let archiver = NSKeyedArchiver.init(requiringSecureCoding: false)
        let attributes = Attributes.init(rawValue: exampleAttributes)
        archiver.encodeRootObject(attributes as Any)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver.init(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        let decodedAttributes = dearchiver.decodeObject() as! Attributes
        verifyDecodedAttributes(attributes: decodedAttributes)
    }
    
    func testInvalidAttributesWithArrayInDict() throws {
        let exampleBogusAttributesWithObjectInArray: [String: Any] = [
            "invalidArrayWithDict": [ 42: ["dict": 24 ]]
        ]
        
        XCTAssertNil(Attributes.init(rawValue: exampleBogusAttributesWithObjectInArray))
    }
    
    func testInvalidAttributesWithBadKey() throws {
        let exampleBogusAttributesWithObjectInArray: [String: Any] = [
            "$%#": 38
        ]
        
        XCTAssertNil(Attributes.init(rawValue: exampleBogusAttributesWithObjectInArray))
    }
}

//
//  RoverDataTests.swift
//  RoverDataTests
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

@testable import RoverData
import XCTest

/// A simple test object to illustrate usage of NSCoding.
class ExampleNSCodingObject: NSObject, NSCoding {
    let myField: Date?
    let myBool: Bool?

    override init() {
        myField = Date()
        myBool = true
        super.init()
    }
    
    init(withDate date: Date?) {
        myField = date
        myBool = true
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.myField, forKey: "myField")
        aCoder.encode(self.myBool, forKey: "myBool")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.myField = aDecoder.decodeObject(forKey: "myField") as? Date
        self.myBool = aDecoder.decodeObject(forKey: "myBool") as? Bool
    }
}

class RoverDataTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNscodingUsage() throws {
        let thingy = ExampleNSCodingObject()
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encodeRootObject(thingy)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        XCTAssertNotNil(dearchiver.decodeObject())
    }
}

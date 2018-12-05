//
//  RoverDataTests.swift
//  RoverDataTests
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverData


class MyThingy: NSObject, NSCoding {
    let myField: Date?
    
    override init() {
        myField = Date()
        super.init()
    }
    
    init(withDate date: Date?) {
        myField = date
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.myField, forKey: "myField")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.myField = aDecoder.decodeObject(forKey: "myField") as? Date
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
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let thingy = MyThingy()
        
        let archiver = NSKeyedArchiver.init(requiringSecureCoding: false)
//        archiver.encode(thingy, forKey: "poop")
        archiver.encodeRootObject(thingy)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        
        //let plist = String.init(data: archivedData, encoding: .utf8)
        

        
        let dearchiver = try NSKeyedUnarchiver.init(forReadingFrom: archivedData)
        
//        XCTAssert(dearchiver.containsValue(forKey: "poop"))
        dearchiver.decodingFailurePolicy = .raiseException
        
        dearchiver.allowedClasses 
        
        XCTAssertNotNil(try dearchiver.)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

//
//  ExperienceTests.swift
//  RoverFoundationTests
//
//  Created by Sean Rucker on 2018-04-15.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverFoundation

class ExperienceTests: XCTestCase {
    func testDecodingPerformance() {
        let url = Bundle(for: type(of: self)).url(forResource: "experience", withExtension: "json")!
        let data = try! Data(contentsOf: url, options: .alwaysMapped)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
        self.measure {
            let _ = try! decoder.decode(Experience.self, from: data)
        }
    }
}

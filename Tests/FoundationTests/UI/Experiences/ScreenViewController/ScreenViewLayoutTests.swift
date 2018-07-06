//
//  ScreenViewLayoutTests.swift
//  RoverFoundationTests
//
//  Created by Sean Rucker on 2018-04-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverFoundation

class ScreenViewLayoutModelServiceTests: XCTestCase {
    func testPrepareLayoutPerformance() {
        let url = Bundle(for: type(of: self)).url(forResource: "experience", withExtension: "json")!
        let data = try! Data(contentsOf: url, options: .alwaysMapped)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
        let experience = try! decoder.decode(Experience.self, from: data)
        let layout = ScreenViewLayout(screen: experience.homeScreen)
        let frame = UIScreen.main.bounds
        
        self.measure {
            layout.prepare(frame: frame)
        }
    }
}

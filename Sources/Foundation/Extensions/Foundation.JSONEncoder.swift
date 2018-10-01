//
//  JSONEncoder.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

extension JSONEncoder {
    public static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
        return encoder
    }()
}

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
        if #available(iOS 11.0, *) {
            // Stable ordering of the keys is very helpful with GraphQL caching on the cloud API side.
            encoder.outputFormatting = [.sortedKeys]
        }
        return encoder
    }()
}

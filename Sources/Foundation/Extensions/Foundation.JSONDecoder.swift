//
//  JSONDecoder.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

extension JSONDecoder {
    public static let `default`: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
        return decoder
    }()
}

//
//  URLRequest.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

extension URLRequest {
    public mutating func setAccountToken(_ accountToken: String) {
        self.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
    }
}

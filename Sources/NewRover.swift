//
//  NewRover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

struct Environment {
    public var accountToken: String?
    public var endpoint: URL = URL(string: "https://api.rover.io/graphql")!
    
    // TODO: to be ripped out:
    public var dispatcherService = DispatcherService()
    
    public var urlSession = URLSession(configuration: URLSessionConfiguration.default)

    var httpClient = HTTPClient(session: urlSession
    ) {
        return AuthContext(accountToken)
    }
}

var Rover = Environment()

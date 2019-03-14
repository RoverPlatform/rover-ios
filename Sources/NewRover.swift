//
//  Rover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// This is
open class Environment {
    public var accountToken: String?
    public var endpoint: URL = URL(string: "https://api.rover.io/graphql")!
    
    // TODO: to be ripped out:
    open lazy private(set) var dispatcherService = DispatcherService()

    open lazy private(set) var urlSession = URLSession(configuration: URLSessionConfiguration.default)

    open lazy private(set) var httpClient = HTTPClient(session: urlSession) {
        return AuthContext(
            accountToken: self.accountToken,
            endpoint: URL(string: "https://api.rover.io/graphql")!
        )
    }
    
    
}


class MyOverriddenRover : Environment {
    private let myCustomDispatcherService = DispatcherService()
    override var dispatcherService: DispatcherService { return self.myCustomDispatcherService }
}

/// This is the central
var Rover: Environment = Environment()


// I will have to use classes instead of structs for one big reason  With classes, I will be able to self-reference, needed for passing dependencies down, AND also supporting callbacks for lazy values. However, with classes you lose the ability to have synthesized initializers. However, this needs public visibility, so this loses that anyway.
// Having to reason about all these constraints is arguably something of a misfeature of Swift, but that could maybe be argued on the basis of optimization.

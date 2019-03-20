//
//  Rover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

/// Set your Rover Account Token (API Key) here.
public var accountToken: String?

/// This object encapsulates the entire object graph of the Rover SDK and all of its internal dependencies.
///
/// It effectively serves as the backplane of the Rover SDK.
open class Environment {
    public var endpoint: URL = URL(string: "https://api.rover.io/graphql")!
    
    open private(set) lazy var urlSession = URLSession(configuration: URLSessionConfiguration.default)

    open private(set) lazy var httpClient = HTTPClient(session: urlSession) {
        AuthContext(
            accountToken: accountToken,
            endpoint: URL(string: "https://api.rover.io/graphql")!
        )
    }
    
    open private(set) lazy var experienceStore = ExperienceStoreService(
        client: httpClient
    )
    
    open private(set) lazy var imageStore = ImageStoreService(session: urlSession)
    
    open private(set) lazy var sessionController = SessionController(keepAliveTime: 10)
    
    /// This is the central entry point to the Rover SDK.  It contains the entire graph of Rover and its internal dependencies, as a global, static singleton.
    public static var shared: Environment = Environment()
}

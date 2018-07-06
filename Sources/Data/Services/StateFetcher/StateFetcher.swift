//
//  StateFetcher.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public protocol StateFetcher {
    var isAutoFetchEnabled: Bool { get set }
    
    func addQueryFragment(_ query: String, fragments: [String]?)
    func addObserver(block: @escaping (Data) -> Void) -> NSObjectProtocol
    func removeObserver(_ token: NSObjectProtocol)
    func fetchState(fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

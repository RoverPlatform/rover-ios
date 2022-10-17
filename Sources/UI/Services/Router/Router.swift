//
//  Router.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
#if !COCOAPODS
import RoverFoundation
#endif

public protocol Router {
    func addHandler(_ handler: RouteHandler)
    
    @discardableResult
    func handle(_ userActivity: NSUserActivity) -> Bool
    
    func action(for userActivity: NSUserActivity) -> Action?
    
    @discardableResult
    func handle(_ url: URL) -> Bool
    
    func action(for url: URL) -> Action?
}

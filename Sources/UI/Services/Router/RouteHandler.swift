//
//  RouteHandler.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol RouteHandler {
    func deepLinkAction(url: URL) -> Action?
    func universalLinkAction(url: URL) -> Action?
}

extension RouteHandler {
    public func deepLinkAction(url: URL) -> Action? {
        return nil
    }
    
    public func universalLinkAction(url: URL) -> Action? {
        return nil
    }
}

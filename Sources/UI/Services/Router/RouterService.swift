//
//  RouterService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

#if !COCOAPODS
import RoverFoundation
#endif

class RouterService: Router {
    let associatedDomains: [String]
    let urlSchemes: [String]
    let dispatcher: Dispatcher
    
    var handlers = [RouteHandler]()
    
    init(associatedDomains: [String], urlSchemes: [String], dispatcher: Dispatcher) {
        self.associatedDomains = associatedDomains
        self.urlSchemes = urlSchemes
        self.dispatcher = dispatcher
    }
    
    func addHandler(_ handler: RouteHandler) {
        handlers.append(handler)
    }
    
    func handle(_ userActivity: NSUserActivity) -> Bool {
        guard let action = action(for: userActivity) else {
            return false
        }
        
        dispatcher.dispatch(action, completionHandler: nil)
        return true
    }
    
    func action(for userActivity: NSUserActivity) -> Action? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            return nil
        }
        
        return action(for: url)
    }
    
    func handle(_ url: URL) -> Bool {
        guard let action = action(for: url) else {
            return false
        }
        
        dispatcher.dispatch(action, completionHandler: nil)
        return true
    }
    
    func action(for url: URL) -> Action? {
        if isUniversalLink(url: url) {
            for handler in handlers {
                if let action = handler.universalLinkAction(url: url) {
                    return action
                }
            }
        } else if isDeepLink(url: url) {
            for handler in handlers {
                if let action = handler.deepLinkAction(url: url) {
                    return action
                }
            }
        }
        
        return nil
    }

    func isUniversalLink(url: URL) -> Bool {
        guard let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            return false
        }
        
        guard let host = url.host, associatedDomains.contains(host) else {
            return false
        }
        
        return true
    }
    
    func isDeepLink(url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }

        return urlSchemes.contains(scheme)
    }
}

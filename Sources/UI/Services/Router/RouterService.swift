//
//  RouterService.swift
//  RoverCampaignsUI
//
//  Created by Sean Rucker on 2018-04-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class RouterService: Router {
    let urlSchemes: [String]
    let dispatcher: Dispatcher
    
    var handlers = [RouteHandler]()
    
    init(urlSchemes: [String], dispatcher: Dispatcher) {
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
       if isDeepLink(url: url) {
            for handler in handlers {
                if let action = handler.deepLinkAction(url: url) {
                    return action
                }
            }
        }
        
        return nil
    }

    func isDeepLink(url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }

        return urlSchemes.contains(scheme)
    }
}

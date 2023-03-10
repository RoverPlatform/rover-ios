// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

import RoverFoundation

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
            guard let domain = url.host, associatedDomains.contains(domain) else {
                return nil
            }
            for handler in handlers {
                if let action = handler.deepLinkAction(url: url, domain: domain) {
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
        
        return isValidDomain(for: url)
    }
    
    func isDeepLink(url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }

        return urlSchemes.contains(scheme)
    }
    
    func isValidDomain(for url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        
        return associatedDomains.contains(host)
    }
}

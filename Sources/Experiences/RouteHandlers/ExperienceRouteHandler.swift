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
import RoverUI

class ExperienceRouteHandler: RouteHandler {
    let actionProvider: (URL) -> RoverFoundation.Action?
    
    init(actionProvider: @escaping (URL) -> RoverFoundation.Action?) {
        self.actionProvider = actionProvider
    }
    
    func deepLinkAction(url: URL, domain: String?) -> RoverFoundation.Action? {
        guard let host = url.host else {
            return nil
        }
        
        //change this so if the host is present experience, we need to transform the url and route to the older vc
        if host == "presentExperience" {
            return classicActionProvider(url: url, domain: domain)
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        //replace the scheme with https
        urlComponents.scheme = "https"
        
        return actionProvider(urlComponents.url!)
    }
    
    func universalLinkAction(url: URL) -> RoverFoundation.Action? {
        let campaignID: String?
        let screenID: String?
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
            campaignID = queryItems.first(where: { $0.name == "campaignID" })?.value
            screenID = queryItems.first(where: { $0.name == "screenID" })?.value
            
        } else {
            campaignID = nil
            screenID = nil
        }
        
        return actionProvider(url)
    }
    
    func classicActionProvider(url: URL, domain: String?) -> RoverFoundation.Action? {
        guard let domain = domain else {
            return nil
        }
        
        if url.host != "presentExperience" {
            return nil
        }
        
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else {
            return nil
        }
        
        guard let experienceID = queryItems.first(where: { $0.name == "experienceID" || $0.name == "id" })?.value else {
            return nil
        }

        var newQueryItems: [URLQueryItem] = []
        let campaignQuery = queryItems.first(where: { $0.name == "campaignID" })
        if let campaignQuery = campaignQuery {
            newQueryItems.append(campaignQuery)
        }
        
        let screenQuery = queryItems.first(where: { $0.name == "screenID" })
        if let screenQuery = screenQuery {
            newQueryItems.append(screenQuery)
        }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = domain
        urlComponents.path = "/v1/experiences/\(experienceID)"
        urlComponents.queryItems = newQueryItems
        
        return actionProvider(urlComponents.url!)
    }
}

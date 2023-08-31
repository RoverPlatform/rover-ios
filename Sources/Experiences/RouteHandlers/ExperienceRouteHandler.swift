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
import os.log

class ExperienceRouteHandler: RouteHandler {
    let actionProvider: (URL) -> RoverFoundation.Action?
    let associatedDomains: [String]
    
    init(actionProvider: @escaping (URL) -> RoverFoundation.Action?, associatedDomains: [String]) {
        self.actionProvider = actionProvider
        self.associatedDomains = associatedDomains
    }
    
    func deepLinkAction(url: URL, domain: String?) -> RoverFoundation.Action? {
        guard let host = url.host else {
            return nil
        }
        
        //change this so if the host is present experience, we need to transform the url and route to the older vc
        if host == "presentExperience" {
            return classicActionProvider(url: url)
        }
        
        // verify that the domain is one of associated domains
        if !associatedDomains.contains(host.lowercased()) {
            return nil
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        //replace the scheme with https
        urlComponents.scheme = "https"
        
        return actionProvider(urlComponents.url!)
    }
    
    func universalLinkAction(url: URL) -> RoverFoundation.Action? {
        guard let host = url.host else {
            return nil
        }
        
        // verify that the domain is one of associated domains
        if !associatedDomains.contains(host.lowercased()) {
            return nil
        }
        
        return actionProvider(url)
    }
    
    func classicActionProvider(url: URL) -> RoverFoundation.Action? {
        // legacy presentExperiences deep links are mapped onto the first Rover domain you have configured.
        guard let hostDomain = associatedDomains.first(where: { domain in
            domain.lowercased().hasSuffix(".rover.io")
        }) else {
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
        urlComponents.host = hostDomain
        urlComponents.path = "/v1/experiences/\(experienceID)"
        if !newQueryItems.isEmpty {
            urlComponents.queryItems = newQueryItems
        }
        
        return actionProvider(urlComponents.url!)
    }
}

//
//  ExperienceRouteHandler.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
#if !COCOAPODS
import RoverFoundation
import RoverUI
#endif

class ExperienceRouteHandler: RouteHandler {
    /// A closure for providing an Action for opening an Experience. (ExperienceID, CampaignID?, ScreenID?).
    let idActionProvider: (String, String?, String?) -> Action?
    let universalLinkActionProvider: (URL, String?, String?) -> Action?
    
    init(idActionProvider: @escaping (String, String?, String?) -> Action?, universalLinkActionProvider: @escaping (URL, String?, String?) -> Action?) {
        self.idActionProvider = idActionProvider
        self.universalLinkActionProvider = universalLinkActionProvider
    }
    
    func deepLinkAction(url: URL) -> Action? {
        guard let host = url.host else {
            return nil
        }
        
        if host != "presentExperience" {
            return nil
        }
        
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else {
            return nil
        }
        
        guard let experienceID = queryItems.first(where: { $0.name == "experienceID" || $0.name == "id" })?.value else {
            return nil
        }

        let campaignID = queryItems.first(where: { $0.name == "campaignID" })?.value
        let screenID = queryItems.first(where: { $0.name == "screenID" })?.value
        
        return idActionProvider(experienceID, campaignID, screenID)
    }
    
    func universalLinkAction(url: URL) -> Action? {
        let campaignID: String?
        let screenID: String?
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
            campaignID = queryItems.first(where: { $0.name == "campaignID" })?.value
            screenID = queryItems.first(where: { $0.name == "screenID" })?.value
            
        } else {
            campaignID = nil
            screenID = nil
        }
        
        return universalLinkActionProvider(url, campaignID, screenID)
    }
}

//
//  ExperienceRouteHandler.swift
//  Rover
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

// TODO: ripout entire routing system and put most of the below in ExperienceViewController.

class ExperienceRouteHandler: RouteHandler {
    typealias ActionProvider = (ExperienceIdentifier) -> Action?
    
    let actionProvider: ActionProvider
    
    init(actionProvider: @escaping ActionProvider) {
        self.actionProvider = actionProvider
    }
    
    func deepLinkAction(url: URL) -> Action? {
        guard let host = url.host else {
            return nil
        }
        
        if host != "presentExperience" {
            return nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let identifier: ExperienceIdentifier
        if let queryItem = components.queryItems?.first(where: { $0.name == "id" }) {
            guard let value = queryItem.value else {
                return nil
            }
            
            let experienceID = ID(rawValue: value)
            identifier = ExperienceIdentifier.experienceID(id: experienceID)
        } else if let queryItem = components.queryItems?.first(where: { $0.name == "campaignID" }) {
            guard let value = queryItem.value else {
                return nil
            }
            
            let campaignID = ID(rawValue: value)
            identifier = ExperienceIdentifier.campaignID(id: campaignID)
        } else {
            return nil
        }
        
        return actionProvider(identifier)
    }
    
    func universalLinkAction(url: URL) -> Action? {
        let identifier = ExperienceIdentifier.campaignURL(url: url)
        return actionProvider(identifier)
    }
}

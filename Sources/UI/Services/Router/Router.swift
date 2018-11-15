//
//  Router.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

public final class Router {
    let associatedDomains: [String]
    let urlSchemes: [String]
    
    let experienceViewControllerProvider: (ExperienceIdentifier) -> UIViewController
    let settingsViewControllerProvider: () -> UIViewController
    let notificationCenterViewControllerProvider: () -> UIViewController
    
    init(associatedDomains: [String], urlSchemes: [String],  experienceViewControllerProvider: @escaping (ExperienceIdentifier) -> UIViewController, settingsViewControllerProvider: @escaping () -> UIViewController, notificationCenterViewControllerProvider: @escaping () -> UIViewController) {
        self.associatedDomains = associatedDomains
        self.urlSchemes = urlSchemes
        self.experienceViewControllerProvider = experienceViewControllerProvider
        self.settingsViewControllerProvider = settingsViewControllerProvider
        self.notificationCenterViewControllerProvider = notificationCenterViewControllerProvider
    }

    public func viewController(for url: URL) -> UIViewController? {
        return viewControllerFor(possibleSettingsURL: url) ?? viewControllerFor(possibleExperienceURL: url) ?? viewControllerFor(possibleNotificationCenterURL: url)
    }
    
    public func viewController(for userActivity: NSUserActivity) -> UIViewController? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            return nil
        }
        return viewController(for: url)
    }
    
    func viewControllerFor(possibleExperienceURL url: URL) -> UIViewController? {
        if isDeepLink(url: url) {
            guard let host = url.host else {
                return nil
            }
            
            if host != "presentExperience" && host != "experience" {
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
            
            return experienceViewControllerProvider(identifier)
        } else if isUniversalLink(url: url) {
            let identifier = ExperienceIdentifier.campaignURL(url: url)
            return experienceViewControllerProvider(identifier)
        } else {
            return nil
        }
    }
    
    func viewControllerFor(possibleSettingsURL url: URL) -> UIViewController? {
        if !isDeepLink(url: url) {
            // Rover notification center may only be opened via a deep link, not a universal link.
            return nil
        }
        
        guard let host = url.host else {
            return nil
        }
        
        if host != "presentSettings" && host != "settings" {
            return nil
        }
        
        return settingsViewControllerProvider()
    }
    
    func viewControllerFor(possibleNotificationCenterURL url: URL) -> UIViewController? {
        if !isDeepLink(url: url) {
            // Rover notification center may only be opened via a deep link, not a universal link.
            return nil
        }

        guard let host = url.host else {
            return nil
        }
        
        if host != "presentNotificationCenter" && host != "notificationCenter" {
            return nil
        }
        
        return notificationCenterViewControllerProvider()
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

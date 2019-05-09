//
//  Analytics.swift
//  Rover
//
//  Created by Sean Rucker on 2019-05-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

public class Analytics {
    public static var shared = Analytics()
    
    private let session = URLSession(configuration: URLSessionConfiguration.default)
    private var tokens: [NSObjectProtocol] = []
    
    public func enable() {
        guard tokens.isEmpty else {
            return
        }
        
        tokens = [
            NotificationCenter.default.addObserver(
                forName: ExperienceViewController.experiencePresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Experience Presented",
                        properties: ExperiencePresentedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ExperienceViewController.experienceDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Experience Dismissed",
                        properties: ExperienceDismissedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ExperienceViewController.experienceViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Experience Viewed",
                        properties: ExperienceViewedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ScreenViewController.screenPresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Screen Presented",
                        properties: ScreenPresentedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ScreenViewController.screenDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Screen Dismissed",
                        properties: ScreenDismissedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ScreenViewController.screenViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Screen Viewed",
                        properties: ScreenViewedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ScreenViewController.blockTappedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Block Tapped",
                        properties: BlockTappedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
        ]
    }
    
    public func disable() {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
    
    deinit {
        disable()
    }
    
    private func trackEvent<Properties>(name: String, properties: Properties) where Properties: Encodable {
        let event = Event(name: name, properties: properties)
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
            data = try encoder.encode(event)
        } catch {
            os_log("Failed to encode analytics event: %@", log: .rover, type: .error, error.localizedDescription)
            return
        }
        
        let url = URL(string: "https://analytics.rover.io")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Rover.accountToken, forHTTPHeaderField: "x-rover-account-token")
        
        var backgroundTaskID: UIBackgroundTaskIdentifier!
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Upload Analytics Event") {
            os_log("Failed to upload analytics event: %@", log: .rover, type: .error, "App was suspended during upload")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        let sessionTask = session.uploadTask(with: request, from: data) { _, _, error in
            if let error = error {
                os_log("Failed to upload analytics event: %@", log: .rover, type: .error, error.localizedDescription)
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        sessionTask.resume()
    }
}

fileprivate struct Event<Properties>: Encodable where Properties: Encodable {
    let name: String
    let properties: Properties
    let timestamp = Date()
    let anonymousID = UIDevice.current.identifierForVendor?.uuidString
    
    enum CodingKeys: String, CodingKey {
        case name = "event"
        case properties
        case timestamp
        case anonymousID
    }
}

fileprivate struct ExperiencePresentedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ExperienceViewController.experienceUserInfoKey] as? Experience else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        
        if let campaignID = userInfo[ExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct ExperienceDismissedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ExperienceViewController.experienceUserInfoKey] as? Experience else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        
        if let campaignID = userInfo[ExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct ExperienceViewedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var duration: Double
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ExperienceViewController.experienceUserInfoKey] as? Experience,
            let duration = userInfo[ExperienceViewController.durationUserInfoKey] as? Double else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.duration = duration
        
        if let campaignID = userInfo[ExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct ScreenPresentedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ScreenViewController.experienceUserInfoKey] as? Experience,
            let screen = userInfo[ScreenViewController.screenUserInfoKey] as? Screen else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        
        if let campaignID = userInfo[ScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct ScreenDismissedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ScreenViewController.experienceUserInfoKey] as? Experience,
            let screen = userInfo[ScreenViewController.screenUserInfoKey] as? Screen else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        
        if let campaignID = userInfo[ScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct ScreenViewedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var duration: Double
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ScreenViewController.experienceUserInfoKey] as? Experience,
            let screen = userInfo[ScreenViewController.screenUserInfoKey] as? Screen,
            let duration = userInfo[ScreenViewController.durationUserInfoKey] as? Double else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        self.duration = duration
        
        if let campaignID = userInfo[ScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

fileprivate struct BlockTappedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var blockID: String
    var blockName: String
    var blockTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ScreenViewController.experienceUserInfoKey] as? Experience,
            let screen = userInfo[ScreenViewController.screenUserInfoKey] as? Screen,
            let block = userInfo[ScreenViewController.blockUserInfoKey] as? Block else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        self.blockID = block.id
        self.blockName = block.name
        self.blockTags = block.tags
        
        if let campaignID = userInfo[ScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

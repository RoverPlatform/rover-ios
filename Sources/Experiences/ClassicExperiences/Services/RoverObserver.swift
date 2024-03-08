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
import os
import RoverFoundation
import RoverData

/// Observes notifications posted by the Rover SDK on the default `NotificationCenter`.
/// For each Rover SDK event an associated Campaign event is tracked, as well as optionally tagging the user when interacting with certain elements
/// added to the `EventQueue`.
public class RoverObserver {
    private let eventQueue: EventQueue
    private let conversionsTracker: ConversionsTrackerService
    private var observers: [NSObjectProtocol] = []
    
    init(eventQueue: EventQueue, conversionsTracker: ConversionsTrackerService) {
        self.eventQueue = eventQueue
        self.conversionsTracker = conversionsTracker
    }
    
    deinit {
        disable()
    }
    
    public func enable() {
        guard observers.isEmpty else {
            return
        }
        
        observers = [
            // MARK: Conversion Tracking
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicBlockTappedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] (notification) in
                    self?.trackConversion(notificationName: ClassicScreenViewController.classicBlockTappedNotification, userInfo: notification.userInfo)
            }),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicPollAnsweredNotification,
                object: nil,
                queue: nil,
                using: { [weak self] (notification) in
                    self?.trackConversion(notificationName: ClassicScreenViewController.classicPollAnsweredNotification, userInfo: notification.userInfo)
            }),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicScreenPresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] (notification) in
                    self?.trackConversion(notificationName: ClassicScreenViewController.classicScreenPresentedNotification, userInfo: notification.userInfo)
            }),
            
            // MARK: Experience Event Tracking
            NotificationCenter.default.addObserver(
                forName: RenderClassicExperienceViewController.classicExperiencePresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackExperiencePresented(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RenderClassicExperienceViewController.classicExperienceDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackExperienceDismissed(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: RenderClassicExperienceViewController.classicExperienceViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackExperienceViewed(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicScreenPresentedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackScreenPresented(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicScreenDismissedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackScreenDismissed(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicScreenViewedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackScreenViewed(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicBlockTappedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackBlockTapped(userInfo: notification.userInfo)
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicPollAnsweredNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackPollAnswered(userInfo: notification.userInfo)
            })
        ]
    }
    
    public func disable() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
    
    private func trackExperiencePresented(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel else {
                return
        }
        
        let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID)
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Experience Presented",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackExperienceDismissed(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel else {
                return
        }
        
        let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID)
        ]
        
        
        let eventInfo = EventInfo(
            name: "Classic Experience Dismissed",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackExperienceViewed(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let duration = userInfo[RenderClassicExperienceViewController.durationUserInfoKey] as? Double else {
                return
        }
        
        let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID),
            "duration": duration
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Experience Viewed",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackScreenPresented(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen else {
                return
        }
                
        let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID),
            "screen": screenAttributes(screen)
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Screen Presented",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
        
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        
        if let callback = experienceManager.registeredScreenViewedCallback {
            callback(
                ScreenViewedEvent(
                    experienceId: experience.id,
                    experienceID: experience.id,
                    experienceName: experience.name,
                    screenId: screen.id,
                    screenID: screen.id,
                    screenName: screen.name,
                    screenProperties: screen.keys,
                    screenTags: Set(screen.tags),
                    campaignId: campaignID,
                    campaignID: campaignID,
                    data: nil,
                    urlParameters: [:]
                )
            )
        }
    }
    
    private func trackScreenDismissed(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen else {
                return
        }
        
        let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID),
            "screen": screenAttributes(screen)
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Screen Dismissed",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackScreenViewed(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let duration = userInfo[ClassicScreenViewController.durationUserInfoKey] as? Double else {
                return
        }
        
        let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID),
            "screen": screenAttributes(screen),
            "duration": duration
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Screen Viewed",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackBlockTapped(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicBlock else {
                return
        }
        
        let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience, campaignID: campaignID),
            "screen": screenAttributes(screen),
            "block": [
                "id": block.id,
                "name": block.name,
                "keys": block.keys,
                "tags": block.tags
            ]
        ]
        
        let eventInfo = EventInfo(
            name: "Classic Block Tapped",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    private func trackPollAnswered(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicBlock,
            let pollOption = userInfo[ClassicScreenViewController.optionUserInfoKey] as? PollOption
            else {
                return
        }
        
        var optionHash = [
            "id": pollOption.id,
            "text": pollOption.text.rawValue
        ]
        
        if let pollImage = (pollOption as? ClassicImagePollBlock.ImagePoll.Option)?.image {
            optionHash["poll"] = pollImage.url.absoluteString
        }
        
        let attributes: Attributes = [
            "experience": experienceAttributes(experience),
            "screen": screenAttributes(screen),
            "block": [
                "id": block.id,
                "name": block.name,
                "keys": block.keys,
                "tags": block.tags
            ],
            "option": optionHash
        ]
        
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            (attributes["experience"] as? Attributes)?["campaignID"] = campaignID
        }
        
        let eventInfo = EventInfo(
            name: "Classic Poll Answered",
            namespace: "rover",
            attributes: attributes
        )
        
        eventQueue.addEvent(eventInfo)
    }
    
    
    private func trackConversion(notificationName: NSNotification.Name, userInfo: [AnyHashable: Any]?) {
        var tag: String?
        
        switch notificationName {
        case ClassicScreenViewController.classicBlockTappedNotification:
            guard let userInfo = userInfo,
                let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicBlock,
                let conversion = block.conversion
                else {
                    return
            }
            
            tag = conversion.tag
            
        case ClassicScreenViewController.classicScreenPresentedNotification:
            guard let userInfo = userInfo,
                let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
                let conversion = screen.conversion else {
                    return
            }
            
            tag = conversion.tag
            
        case ClassicScreenViewController.classicPollAnsweredNotification:
            guard let userInfo = userInfo,
                let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicBlock,
                let pollOption = userInfo[ClassicScreenViewController.optionUserInfoKey] as? PollOption,
                let conversion = block.conversion else {
                    return
            }
            
            let formattedPollOption = pollOption.text.rawValue.replacingOccurrences(of: " ", with: "_").lowercased()
            tag = "\(conversion.tag)_\(formattedPollOption)"
            
        default:
            return
        }
                
        if let tag = tag {
            conversionsTracker.track(tag)
        }
    }
    
    private func experienceAttributes(_ experience: ClassicExperienceModel, campaignID: String? = nil) -> [String: Any] {
        let experienceAttributes: [String: Any?] = [
            "id": experience.id,
            "name": experience.name,
            "keys": experience.keys,
            "tags": experience.tags,
            "campaignId" : campaignID,
            "url": experience.sourceUrl?.absoluteString
        ]
        
        return experienceAttributes.compactMapValues { $0 }
    }
    
    private func screenAttributes(_ screen: ClassicScreen) -> [String: Any] {
        return [
            "id": screen.id,
            "name": screen.name,
            "keys": screen.keys,
            "tags": screen.tags
        ]
    }
}

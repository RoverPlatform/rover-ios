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

import os.log
import UIKit
import RoverFoundation
import RoverData

class MiniAnalytics {
    /// The shared singleton analytics service.
    static var shared = MiniAnalytics()
    
    private let session = URLSession(configuration: URLSessionConfiguration.default)
    private var tokens: [NSObjectProtocol] = []
    
    func enable() {
        guard tokens.isEmpty else {
            return
        }
        
        tokens = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil,
                using: { [weak self] notification in
                    self?.trackEvent(name: "App Opened", properties: EmptyProperties())
                }
            ),
            
            NotificationCenter.default.addObserver(
                forName: RenderClassicExperienceViewController.classicExperiencePresentedNotification,
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
                forName: RenderClassicExperienceViewController.classicExperienceDismissedNotification,
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
                forName: RenderClassicExperienceViewController.classicExperienceViewedNotification,
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
                forName: ClassicScreenViewController.classicScreenPresentedNotification,
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
                forName: ClassicScreenViewController.classicScreenDismissedNotification,
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
                forName: ClassicScreenViewController.classicScreenViewedNotification,
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
                forName: ClassicScreenViewController.classicBlockTappedNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(
                        name: "Block Tapped",
                        properties: BlockTappedProperties(userInfo: $0.userInfo)
                    )
                }
            ),
            NotificationCenter.default.addObserver(
                forName: ClassicScreenViewController.classicPollAnsweredNotification,
                object: nil,
                queue: nil,
                using: { [weak self] in
                    self?.trackEvent(name: "Poll Answered", properties: PollAnsweredProperties(userInfo: $0.userInfo))
                }
            )
        ]
    }
    
    func disable() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens = []
    }
    
    deinit {
        disable()
    }
    
    private func trackEvent<Properties>(name: String, properties: Properties) where Properties: Encodable {
        //TODO: adjust analytics to match the rest of the SDK
        let accountToken = Rover.shared.resolve(HTTPClient.self)!.accountToken
        
        let event = Event(name: name, properties: properties)
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
            data = try encoder.encode(event)
        } catch {
            os_log("Failed to encode analytics event: %@", log: .rover, type: .error, error.debugDescription)
            return
        }
        
        let url = URL(string: "https://analytics.rover.io")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
        request.setRoverUserAgent()
        
        var backgroundTaskID: UIBackgroundTaskIdentifier!
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Upload Analytics Event") {
            os_log("Failed to upload analytics event: %@", log: .rover, type: .error, "App was suspended during upload")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        let sessionTask = session.uploadTask(with: request, from: data) { _, _, error in
            if let error = error {
                os_log("Failed to upload analytics event: %@", log: .rover, type: .error, error.debugDescription)
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        sessionTask.resume()
    }
}

private struct Event<Properties>: Encodable where Properties: Encodable {
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

private struct ExperiencePresentedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        
        if let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct ExperienceDismissedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        
        if let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct ExperienceViewedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var duration: Double
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[RenderClassicExperienceViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let duration = userInfo[RenderClassicExperienceViewController.durationUserInfoKey] as? Double else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.duration = duration
        
        if let campaignID = userInfo[RenderClassicExperienceViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct ScreenPresentedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct ScreenDismissedProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct ScreenViewedProperties: Encodable {
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
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let duration = userInfo[ClassicScreenViewController.durationUserInfoKey] as? Double else {
                return nil
        }
        
        self.experienceID = experience.id
        self.experienceName = experience.name
        self.experienceTags = experience.tags
        self.screenID = screen.id
        self.screenName = screen.name
        self.screenTags = screen.tags
        self.duration = duration
        
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct BlockTappedProperties: Encodable {
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
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicBlock else {
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
        
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct PollAnsweredProperties: Encodable {
    var experienceID: String
    var experienceName: String
    var experienceTags: [String]
    var screenID: String
    var screenName: String
    var screenTags: [String]
    var blockID: String
    var blockName: String
    var blockTags: [String]
    var optionID: String
    var optionText: String
    var optionImage: String? // URL
    var campaignID: String?
    
    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
            let experience = userInfo[ClassicScreenViewController.experienceUserInfoKey] as? ClassicExperienceModel,
            let screen = userInfo[ClassicScreenViewController.screenUserInfoKey] as? ClassicScreen,
            let block = userInfo[ClassicScreenViewController.blockUserInfoKey] as? ClassicPollBlock,
            let option = userInfo[ClassicScreenViewController.optionUserInfoKey] as? PollOption
        else {
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
        self.optionID = option.id
        self.optionText = option.text.rawValue
        self.optionImage = (option as? ClassicImagePollBlock.ImagePoll.Option)?.image?.url.absoluteString
        if let campaignID = userInfo[ClassicScreenViewController.campaignIDUserInfoKey] as? String {
            self.campaignID = campaignID
        }
    }
}

private struct EmptyProperties: Encodable {
}

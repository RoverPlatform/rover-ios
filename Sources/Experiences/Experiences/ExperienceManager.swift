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

import BackgroundTasks
import Combine
import os.log
import UIKit
import RoverFoundation
import RoverData

// This class holds and manages caches, view controllers and callbacks as necessary for experiences.  This class does not apply to classic experiences.
final class ExperienceManager {
    let eventQueue: EventQueue
    let userInfoContextProvider: UserInfoContextProvider
    
    var userInfo: [String: Any] {
        userInfoContextProvider.userInfo?.flatRawValue() ?? [:]
    }
    
    
    internal var registeredCustomActionCallback: ((CustomActionActivationEvent) -> Void)?
    internal var registeredScreenViewedCallback: ((ScreenViewedEvent) -> Void)?
    internal var authorizers: [Authorizer] = []
    
    init(eventQueue: EventQueue, userInfoContextProvider: UserInfoContextProvider) {
        self.eventQueue = eventQueue
        self.userInfoContextProvider = userInfoContextProvider
    }
    
    internal lazy var downloader: AssetsDownloader = AssetsDownloader(cache: self.assetsURLCache)

    static let userDefaults = UserDefaults(suiteName: "io.rover.RoverSDK")!
    
    /// Rover SDK's URLCache
    lazy var urlCache: URLCache = .makeRoverDefaultCache()

    /// Downloaded assets cache.
    lazy var assetsURLCache: URLCache = .makeRoverAssetsDefaultCache()

    /// This NSCache is used to retain references to images loaded for display in Experiences.  The images are not given calculated costs, so `totalCostLimit` should be in terms of total images, not bytes of memory.
    lazy var imageCache: NSCache<NSURL, UIImage> = .roverDefaultImageCache()
    
    /// The libdispatch queue used for fetching and decoding images.
    lazy var imageFetchAndDecodeQueue: DispatchQueue = DispatchQueue(label: "io.rover.ImageFetchAndDecode", attributes: .concurrent)
    
    let navBarViewController =
        NavBarViewController.init(experience:screen:data:urlParameters:userInfo:authorize:)
    
    let screenViewController = ScreenViewController.init(experience:screen:data:urlParameters:userInfo:authorize:)
}

// MARK: Notifications

extension ExperienceManager {
    /// Posted when a screen is viewed.
    ///
    /// The Rover SDK posts this notification when the user views a screen in a Rover experience.
    ///
    /// The `userInfo` dictionary contains the following information:
    /// -  `experience`: The `Experience` the screen belongs to.
    /// -  `screen`: The `Screen` that was viewed.
    /// -  `data`: The JSON data available to the screen at the time it was viewed.
    public static let screenViewedNotification: Notification.Name = Notification.Name("RoverScreenViewedNotification")
    
    public static let didRegisterCustomFontNotification = NSNotification.Name("RoverDidRegisterCustomFontNotification")
}

// MARK: Authorizers

struct Authorizer {
    var pattern: String
    var block: (inout URLRequest) -> Void
    
    func authorize(_ request: inout URLRequest) {
        block(&request)
    }
}

extension ExperienceManager {
    public func authorize(_ pattern: String, with block: @escaping (inout URLRequest) -> Void) {
        authorizers.append(
            Authorizer(pattern: pattern, block: block)
        )
    }
    
    func authorize(_ request: inout URLRequest) {
        guard let host = request.url?.host else {
            return
        }
        
        let requestTokens = Array(host.split(separator: "."))
        guard requestTokens.count >= 2 else {
            return
        }
        
        for authorizer in self.authorizers {
            let wildcardAndRoot = authorizer.pattern.components(separatedBy: "*.")
            guard let root = wildcardAndRoot.last, wildcardAndRoot.count <= 2 else {
                break
            }
            
            let hasWildcard = wildcardAndRoot.count > 1
            
            if (!hasWildcard && host == authorizer.pattern) || (hasWildcard && (host == root || host.hasSuffix(".\(root)"))) {
                authorizer.authorize(&request)
            }
        }
    }
}

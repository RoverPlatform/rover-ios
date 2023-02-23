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

import UIKit
import os.log
import RoverFoundation
import RoverData

/// Use this View Controller to present Experiences to the user.
///
/// - Tag: ExperienceViewController
class RenderExperienceViewController: UIViewController {
    
    private var campaignID: String?
    
    /// Initialize Experience View Controller with a `Experience`
    /// If a local file URL is used, the initialScreenId, urlParameter, userInfo and authorize will be overriden by the local file's values.
    /// - Parameters:
    ///   - experience: `Experience` instance
    ///   - screenID: Optional. Override experience's initial screen identifier.
    ///   - urlParameters: Optional parameters from the URL used to launch the experience.
    ///   - userInfo: Optional properties about the current user which can be used to personalize the experience.
    ///   - authorize: Optional callback to authorize URL reqeusts made by `DataSource`s.
    
    init(
        experience: ExperienceModel,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorize: @escaping (inout URLRequest) -> Void = { _ in }
    ) {
        super.init(nibName: nil, bundle: nil)
        
        let context = LaunchContext(
            initialScreenID: urlParameters["screenID"],
            urlParameters: urlParameters,
            userInfo: userInfo,
            authorize: authorize
        )
        
        self.campaignID = urlParameters["campaignID"]
        
        presentExperience(experience: experience, context: context)
    }
    
    /// Initialize Experience View Controller with a `Experience`, for use with a Segue Outlet in a Storyboard.
    /// If a local file URL is used, the initialScreenId, urlParameter, userInfo and authorize will be overriden by the local file's values.
    /// - Parameters:
    ///   - experience: `Experience` instance
    ///   - coder: An NSCoder
    ///   - screenID: Optional. Override experience's initial screen identifier.
    ///   - urlParameters: Optional parameters from the URL used to launch the experience.
    ///   - userInfo: Optional properties about the current user which can be used to personalize the experience.
    ///   - authorize: Optional callback to authorize URL reqeusts made by `DataSource`s.
    
    init?(
        experience: ExperienceModel,
        coder: NSCoder,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorize: @escaping (inout URLRequest) -> Void = { _ in }
    ) {
        super.init(coder: coder)
        
        let context = LaunchContext(
            initialScreenID: urlParameters["screenID"],
            urlParameters: urlParameters,
            userInfo: userInfo,
            authorize: authorize
        )
        
        self.campaignID = urlParameters["campaignID"]
        
        presentExperience(experience: experience, context: context)
    }
    
    required init?(coder: NSCoder) {
        fatalError("ExperienceViewController is not supported directly in Interface Builder or Storyboards, instead use a Segue outlet factory method with init?(url:coder:ignoreCache)")
    }
    
    override var childForStatusBarStyle: UIViewController? {
        children.first
    }
    
    override var childForStatusBarHidden: UIViewController? {
        children.first
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    
    private struct LaunchContext {
        var initialScreenID: Screen.ID?
        var urlParameters = [String: String]()
        var userInfo = [String: Any]()
        var authorize: (inout URLRequest) -> Void = { _ in }
    }
    
    private func presentExperience(experience: ExperienceModel, context: LaunchContext) {
        let initialScreenID = context.initialScreenID ?? experience.initialScreenID
        
        // determine which root container is on the path to the initial screen:
        let matchingScreen = experience.nodes.first(where: { $0.id == initialScreenID }) as? Screen
        
        guard let initialScreen = matchingScreen ?? experience.nodes.first(where: { $0 is Screen }) as? Screen else {
            rover_log(.error, "No screen to start the Experience from. Giving up.")
            return
        }
        
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        
        // Register experience fonts
        experience.fontURLs.forEach { url in
            if url.isFileURL {
                do {
                    let fontData = try Data(contentsOf: url)
                    try self.registerFontIfNeeded(data: fontData)
                } catch {
                    rover_log(.error, "Failed to decode presumably corrupted cached font data. Font will not be loaded.  Error: %s", error.debugDescription)
                }
            } else {
                experienceManager.downloader.download(url: url) { result in
                    do {
                        try self.registerFontIfNeeded(data: result.get())
                    } catch {
                        rover_log(.error, "Failed to decode presumably corrupted cached font data. Removing it to allow for re-fetch. Error: %s", error.debugDescription)
                        experienceManager.assetsURLCache.removeCachedResponse(for: URLRequest(url: url))
                    }
                }
            }
        }
        
        observeScreenViews()
        
        let navViewController = experienceManager.navBarViewController(
            experience,
            initialScreen,
            nil,
            context.urlParameters,
            context.userInfo,
            context.authorize
        )
        
        self.restorationIdentifier = String(describing: experience.id)
        self.setChildViewController(navViewController)
    }
    
    private func registerFontIfNeeded(data: Data) throws {
        struct FontRegistrationError: Swift.Error, LocalizedError {
            let message: String
            
            var errorDescription: String? {
                message
            }
        }
        
        guard let fontProvider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(fontProvider),
              let fontName = cgFont.postScriptName as String?
        else {
            throw FontRegistrationError(message: "Unable to register font from provided data.")
        }
        
        let queryCollection = CTFontCollectionCreateWithFontDescriptors(
            [
                CTFontDescriptorCreateWithAttributes(
                    [kCTFontNameAttribute: fontName] as CFDictionary
                )
            ] as CFArray, nil
        )
        
        let fontExists = (CTFontCollectionCreateMatchingFontDescriptors(queryCollection) as? [CTFontDescriptor])?.isEmpty == false
        if !fontExists {
            if !CTFontManagerRegisterGraphicsFont(cgFont, nil) {
                throw FontRegistrationError(message: "Unable to register font: \(fontName)")
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: ExperienceManager.didRegisterCustomFontNotification, object: fontName)
            }
        }
    }
    
    private func setChildViewController(_ childViewController: UIViewController) {
        if let existingChildViewController = self.children.first {
            existingChildViewController.willMove(toParent: nil)
            existingChildViewController.view.removeFromSuperview()
            existingChildViewController.removeFromParent()
        }
        
        addChild(childViewController)
        childViewController.view.frame = view.bounds
        view.addSubview(childViewController.view)
        childViewController.didMove(toParent: self)
    }
    
    private var screenViewedObserver: NSObjectProtocol?
    
    private func observeScreenViews() {
        screenViewedObserver = NotificationCenter.default.addObserver(
            forName: ExperienceManager.screenViewedNotification,
            object: nil,
            queue: OperationQueue.main,
            using: { notification in
                let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
                
                let screen = notification.userInfo!["screen"] as! Screen
                let experience = notification.userInfo!["experience"] as! ExperienceModel
                let data = notification.userInfo!["data"] as Any
                
                let event = EventInfo.screenViewedEvent(with: self.campaignID, experience: experience, screen: screen)
                experienceManager.eventQueue.addEvent(event)
                
                if let callback = experienceManager.registeredScreenViewedCallback {
                    callback(
                        ScreenViewedEvent(
                            experienceId: experience.id,
                            experienceName: experience.name,
                            screenId: screen.id,
                            screenName: screen.name,
                            nodeProperties: screen.metadata?.properties ?? [:],
                            nodeTags: screen.metadata?.tags ?? [],
                            campaignId: self.campaignID,
                            data: data,
                            urlParameters: experience.urlParameters
                        )
                    )
                }
            }
        )
    }
    
    deinit {
        if let screenViewedObserver = self.screenViewedObserver {
            NotificationCenter.default.removeObserver(screenViewedObserver)
        }
    }
}

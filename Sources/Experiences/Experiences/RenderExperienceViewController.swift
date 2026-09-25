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

import RoverData
import RoverFoundation
import UIKit
import os.log

/// Use this View Controller to present Experiences to the user.
///
/// - Tag: ExperienceViewController
class RenderExperienceViewController: UIViewController {

    /// Initialize Experience View Controller with a `Experience`
    /// If a local file URL is used, the initialScreenId, urlParameter, userInfo and authorize will be overriden by the local file's values.
    /// - Parameters:
    ///   - experience: `Experience` instance
    ///   - screenID: Optional. Override experience's initial screen identifier.
    ///   - urlParameters: Optional parameters from the URL used to launch the experience.
    ///   - userInfo: Optional properties about the current user which can be used to personalize the experience.
    ///   - authorizers: Authorize URL reqeusts made by `DataSource`s.

    init(
        experience: ExperienceModel,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorizers: Authorizers
    ) {
        super.init(nibName: nil, bundle: nil)

        let context = LaunchContext(
            initialScreenID: urlParameters["screenID"],
            urlParameters: urlParameters,
            userInfo: userInfo,
            authorizers: authorizers
        )

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
        authorizers: Authorizers
    ) {
        super.init(coder: coder)

        let context = LaunchContext(
            initialScreenID: urlParameters["screenID"],
            urlParameters: urlParameters,
            userInfo: userInfo,
            authorizers: authorizers
        )

        presentExperience(experience: experience, context: context)
    }

    required init?(coder: NSCoder) {
        fatalError(
            "ExperienceViewController is not supported directly in Interface Builder or Storyboards, instead use a Segue outlet factory method with init?(url:coder:ignoreCache)"
        )
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
        var authorizers: Authorizers
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
        ExperienceFontLoader.loadFonts(for: experience, experienceManager: experienceManager)

        experienceManager.observeScreenViews()

        let navViewController = experienceManager.navBarViewController(
            experience,
            initialScreen,
            nil,
            context.urlParameters,
            context.userInfo,
            context.authorizers
        )

        self.restorationIdentifier = String(describing: experience.id)
        self.setChildViewController(navViewController)
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
}

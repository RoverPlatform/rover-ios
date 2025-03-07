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
import RoverFoundation
import os.log

/// The `RoverViewController` fetches experiences from Rover's server and displays a loading screen while it is loading.
/// The loading screen can be customized by overriding the `loadingViewController()` method and supplying your own. The
/// Rover SDK comes with a default loading screen `LoadingViewController` which you can override and customize to suit
/// your needs. You can also supply your own view controller.
open class ExperienceViewController: UIViewController {
    #if swift(>=4.2)
    override open var childForStatusBarStyle: UIViewController? {
        return self.children.first
    }
    #else
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        return self.childViewControllers.first
    }
    #endif
    
    private var url: URL?
    private var experienceStore: ExperienceStore = Rover.shared.resolve(ExperienceStore.self)!
    
    /// Load a Rover experience into a newly instantiated ExperienceViewController.
    /// This URL can be:
    ///  * a file URL
    ///  * an HTTP URL
    ///  * a deeplink
    ///  * a universal link
    ///
    /// - Parameter url: The URL  associated with the experience to load.
    public static func openExperience(with experienceUrl: URL) -> ExperienceViewController {
        let experienceViewController = ExperienceViewController()
        experienceViewController.loadExperience(with: experienceUrl)
        return experienceViewController
    }
    
    /// Load a Rover experience into the view controller referenced by its URL.
    /// This can be:
    ///  * a file URL
    ///  * an HTTP URL
    ///  * a deeplink
    ///  * a universal link
    ///
    /// - Parameter url: The URL  associated with the experience to load.
    public func loadExperience(with url: URL) {
        self.url = url
        loadExperience()
    }
    
    private func loadExperience() {
        guard let url = url else {
            return
        }
        
        let loadingViewController = self.loadingViewController()
        setChildViewController(loadingViewController)
        
        experienceStore.fetchExperience(for: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }

                switch result {
                case let .failure(error):
                    os_log("Unable to load experience (from url %s) due to: %s", log: .experiences, type: .error, url.toString(), error.debugDescription)
                    self.showError(error: error, shouldRetry: error.isRetryable)
                case let .success(experience):
                    let viewController = self.renderViewController(experience: experience)
                    
                    self.setChildViewController(viewController)
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }
    
    #if swift(>=4.2)
    private func setChildViewController(_ childViewController: UIViewController) {
        if let existingChildViewController = self.children.first {
            existingChildViewController.willMove(toParent: nil)
            existingChildViewController.view.removeFromSuperview()
            existingChildViewController.removeFromParent()
        }
        
        childViewController.willMove(toParent: self)
        addChild(childViewController)
        childViewController.view.frame = view.bounds
        view.addSubview(childViewController.view)
        childViewController.didMove(toParent: self)
    }
    #else
    private func setChildViewController(_ childViewController: UIViewController) {
        if let existingChildViewController = self.childViewControllers.first {
            existingChildViewController.willMove(toParentViewController: nil)
            existingChildViewController.view.removeFromSuperview()
            existingChildViewController.removeFromParentViewController()
        }
        
        childViewController.willMove(toParentViewController: self)
        addChildViewController(childViewController)
        childViewController.view.frame = view.bounds
        view.addSubview(childViewController.view)
        childViewController.didMove(toParentViewController: self)
    }
    #endif
    
    private func showError(error: Error?, shouldRetry: Bool) {
        if self.presentingViewController != nil {
            presentError(shouldRetry: shouldRetry)
        } else {
            embedError(shouldRetry: shouldRetry)
        }
    }
    
    private func embedError(shouldRetry: Bool) {
        let errorViewController = ErrorViewController(shouldRetry: shouldRetry) {
            self.loadExperience()
        }
        
        self.setChildViewController(errorViewController)
    }
    
    private func presentError(shouldRetry: Bool) {
        let alertController: UIAlertController
        if shouldRetry {
            alertController = UIAlertController(
                title: NSLocalizedString("Error", comment: "Rover Error Dialog Title"),
                message: NSLocalizedString("Failed to load experience", comment: "Rover Failed to load experience error message"),
                preferredStyle: UIAlertController.Style.alert
            )
            let cancel = UIAlertAction(
                title: NSLocalizedString("Cancel", comment: "Rover Cancel Action"),
                style: UIAlertAction.Style.cancel
            ) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
            let retry = UIAlertAction(
                title: NSLocalizedString("Try Again", comment: "Rover Try Again Action"),
                style: UIAlertAction.Style.default
            ) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.loadExperience()
            }
            
            alertController.addAction(cancel)
            alertController.addAction(retry)
        } else {
            alertController = UIAlertController(
                title: NSLocalizedString("Error", comment: "Rover Error Title"),
                message: NSLocalizedString("Something went wrong", comment: "Rover Something Went Wrong message"),
                preferredStyle: UIAlertController.Style.alert
            )

            let ok = UIAlertAction(
                title: NSLocalizedString("Ok", comment: "Rover Ok Action"),
                style: UIAlertAction.Style.default
            ) { _ in
                alertController.dismiss(animated: false, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
                        
            alertController.addAction(ok)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Factories
    
    /// Construct a view controller to display while loading an experience from Rover's server. The default
    /// returns an instance `LoadingViewController`. You can override this method if you want to use a different view
    /// controller.
    open func loadingViewController() -> UIViewController {
        return LoadingViewController()
    }
    
    private func renderViewController(experience: LoadedExperience) -> UIViewController {
        switch experience {
        case .classic(let classicExperienceModel, let urlParameters):
            return RenderClassicExperienceViewController(
                experience: classicExperienceModel,
                campaignID: urlParameters["campaignID"],
                initialScreenID: urlParameters["screenID"])
            
        case .standard(
            let experienceModel,
            let urlParameters):
            let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
            return RenderExperienceViewController(
                experience: experienceModel,
                urlParameters: urlParameters,
                userInfo: experienceManager.userInfo,
                authorizers: experienceManager.authorizers)
            
        case .file(
            let experienceModel,
            let urlParameters,
            let userInfo,
            let authorizers):
            return RenderExperienceViewController(
                experience: experienceModel,
                urlParameters: urlParameters,
                userInfo: userInfo,
                authorizers: authorizers)
        }
    }
}

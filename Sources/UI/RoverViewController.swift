//
//  RoverViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2018-02-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import SafariServices
import os
import UIKit

/// The `RoverViewController` is a container for loading and displaying a Rover experience. The `RoverViewController`
/// can be instantiated manually or in a story board. After the view controller is instantiated, its primary API is the
/// `loadExperience(id:campaignID:)` and `loadExperience(universalLink:campaignID:)` methods which present to ways of
/// identifying the experience to load. Before calling either of these methods make sure you've set the
/// `Rover.accountToken` variable to match the SDK token found in the Rover Settings app.
///
/// The `RoverViewController` fetches experiences from Rover's server and displays a loading screen while it is loading.
/// The loading screen can be customized by overriding the `loadingViewController()` method and supplying your own. The
/// Rover SDK comes with a default loading screen `LoadingViewController` which you can override and customize to suit
/// your needs. You can also supply your own view controller.
open class RoverViewController: UIViewController {
    override open var childForStatusBarStyle: UIViewController? {
        return self.children.first
    }
    
    private var campaignID: String?
    private var identifier: ExperienceStore.Identifier?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        Analytics.shared.enable()
    }
    
    /// Load a Rover experience into the view controller referenced by its ID.
    ///
    /// - Parameter id: The ID of the experience to load.
    public func loadExperience(id: String, campaignID: String? = nil) {
        self.campaignID = campaignID
        self.identifier = ExperienceStore.Identifier.experienceID(id: id)
        loadExperience()
    }
    
    /// Load a Rover experience into the view controller referenced by its associated universal link.
    ///
    /// - Parameter universalLink: The universal link associated with the experience to load.
    public func loadExperience(universalLink url: URL, campaignID: String? = nil) {
        self.campaignID = campaignID
        self.identifier = ExperienceStore.Identifier.experienceURL(url: url)
        loadExperience()
    }
    
    private func loadExperience() {
        guard let identifier = identifier else {
            return
        }
        
        if let experience = ExperienceStore.shared.experience(for: identifier) {
            let viewController = experienceViewController(experience: experience)
            setChildViewController(viewController)
            return
        }
        
        let loadingViewController = self.loadingViewController()
        setChildViewController(loadingViewController)
        
        ExperienceStore.shared.fetchExperience(for: identifier) { [weak self] result in
            guard let self = self else {
                return
            }
            
            DispatchQueue.main.async {
                switch result {
                case let .failure(error):
                    self.present(error: error, shouldRetry: error.isRetryable)
                case let .success(experience):
                    let viewController = self.experienceViewController(
                        experience: experience
                    )
                    
                    self.setChildViewController(viewController)
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }
    
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
    
    private func present(error: Error?, shouldRetry: Bool) {
        let alertController: UIAlertController
        
        if shouldRetry {
            alertController = UIAlertController(title: "Error", message: "Failed to load experience", preferredStyle: UIAlertController.Style.alert)
            let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
            let retry = UIAlertAction(title: "Try Again", style: UIAlertAction.Style.default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.loadExperience()
            }
            
            alertController.addAction(cancel)
            alertController.addAction(retry)
        } else {
            alertController = UIAlertController(title: "Error", message: "Something went wrong", preferredStyle: UIAlertController.Style.alert)
            let ok = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default) { _ in
                alertController.dismiss(animated: false, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
                        
            alertController.addAction(ok)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Factories
    
    open func loadingViewController() -> UIViewController {
        return LoadingViewController()
    }
    
    open func presentWebsiteViewController(url: URL) -> UIViewController {
        return SFSafariViewController(url: url)
    }
    
    open func screenViewLayout(screen: Screen) -> UICollectionViewLayout {
        return ScreenViewLayout(screen: screen)
    }
    
    open func presentWebsite(sourceViewController: UIViewController, url: URL) {
        // open a link using an embedded web browser controller.
        let webViewController = SFSafariViewController(url: url)
        sourceViewController.present(webViewController, animated: true, completion: nil)
    }
    
    open func screenViewController(experience: Experience, screen: Screen) -> ScreenViewController {
        return ScreenViewController(
            collectionViewLayout: screenViewLayout(screen: screen),
            experience: experience,
            campaignID: self.campaignID,
            screen: screen,
            viewControllerProvider: { (experience: Experience, screen: Screen) in
                self.screenViewController(experience: experience, screen: screen)
        },
            presentWebsite: { (url: URL, sourceViewController: UIViewController) in
                self.presentWebsite(sourceViewController: sourceViewController, url: url)
        })
    }
    
    open func experienceViewController(experience: Experience) -> ExperienceViewController {
        let homeScreenViewController = screenViewController(experience: experience, screen: experience.homeScreen)
        return ExperienceViewController(
            homeScreenViewController: homeScreenViewController,
            experience: experience,
            campaignID: self.campaignID
        )
    }
}

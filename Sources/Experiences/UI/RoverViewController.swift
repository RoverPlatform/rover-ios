//
//  RoverViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2018-02-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit
import RoverFoundation

/// The `RoverViewController` is a container for loading and displaying a Rover experience. The `RoverViewController`
/// can be instantiated manually or in a story board. After the view controller is instantiated, its primary API is the
/// `loadExperience(id:campaignID:)` and `loadExperience(universalLink:campaignID:)` methods which present two ways of
/// identifying the experience to load. Before calling either of these methods make sure you've set the
/// `Rover.accountToken` variable to match the SDK token found in the Rover Settings app.
///
/// The `RoverViewController` fetches experiences from Rover's server and displays a loading screen while it is loading.
/// The loading screen can be customized by overriding the `loadingViewController()` method and supplying your own. The
/// Rover SDK comes with a default loading screen `LoadingViewController` which you can override and customize to suit
/// your needs. You can also supply your own view controller.
open class RoverViewController: UIViewController {
    #if swift(>=4.2)
    override open var childForStatusBarStyle: UIViewController? {
        return self.children.first
    }
    #else
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        return self.childViewControllers.first
    }
    #endif
    
    private var campaignID: String?
    private var initialScreenID: String?
    private var identifier: ExperienceIdentifier?
    private var experienceStore: ExperienceStore? = RoverFoundation.shared?.resolve(ExperienceStore.self)
    
    /// Load a Rover experience into the view controller referenced by its ID.
    ///
    /// - Parameter id: The ID of the experience to load.
    public func loadExperience(id: String, campaignID: String? = nil, useDraft: Bool = false, initialScreenID: String? = nil) {
        self.campaignID = campaignID
        self.initialScreenID = initialScreenID
        self.identifier = ExperienceIdentifier.experienceID(id: id, useDraft: useDraft)
        loadExperience()
    }
    
    /// Load a Rover experience into the view controller referenced by its associated universal link.
    ///
    /// - Parameter universalLink: The universal link associated with the experience to load.
    public func loadExperience(universalLink url: URL, campaignID: String? = nil, initialScreenID: String? = nil) {
        self.campaignID = campaignID
        self.initialScreenID = initialScreenID
        self.identifier = ExperienceIdentifier.experienceURL(url: url)
        loadExperience()
    }
    
    /// Present an Experience directly into the view controller without downloading one by an identifier.
    public func loadExperience(experience: Experience, campaignID: String? = nil, initialScreenID: String? = nil) {
        self.campaignID = campaignID
        self.initialScreenID = initialScreenID
        let viewController = experienceViewController(experience: experience)
        setChildViewController(viewController)
        self.setNeedsStatusBarAppearanceUpdate()
        return
    }
    
    private func loadExperience() {
        guard let identifier = identifier, let experienceStore = experienceStore else {
            return
        }
        
        if let experience = experienceStore.experience(for: identifier) {
            let viewController = experienceViewController(experience: experience)
            setChildViewController(viewController)
            return
        }
        
        let loadingViewController = self.loadingViewController()
        setChildViewController(loadingViewController)
        
        experienceStore.fetchExperience(for: identifier) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                
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
    
    private func present(error: Error?, shouldRetry: Bool) {
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
    
    /// Construct a view controller to display for a given experience. The default implementation returns an instance of
    /// `ExperienceViewController`. You can override this method if you want to use a different view controller.
    open func experienceViewController(experience: Experience) -> UIViewController {
        return ExperienceViewController(experience: experience, campaignID: self.campaignID, initialScreenID: self.initialScreenID)
    }
}

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

public protocol RoverViewControllerDelegate: AnyObject {
    /// Tells the delegate that the view controller for a given experience was presented.
    func viewController(_ viewController: RoverViewController, didPresentExperience experience: Experience)
    
    /// Tells the delegate that the view controller for a given experience was dismissed.
    func viewController(_ viewController: RoverViewController, didDismissExperience experience: Experience)
    
    /// Tells the delegate that the view controller for a given experience was viewed for a period of time. The view controller keeps the viewing "session" alive if it is dismissed and presented again within a short period time. It also keeps the session alive if the app is put to the background and restored again within a short period of time. For this reason, this delegate method is only called after the view controller is certain the session has ended. If the duration of time the experience was viewed is important you should use this method. However if you only need to be notified when the experience is initially presented, you are better suited to use the `viewController(_:, didPresentExperience:)` method.
    func viewController(_ viewController: RoverViewController, didViewExperience experience: Experience, duration: Double)
    
    /// Tells the delegate that the view controller presented a chid view controller for a specific screen.
    func viewController(_ viewController: RoverViewController, didPresentScreen screen: Screen, experience: Experience)
    
    /// Tells the delegate that the view controller dismissed a child view controller for a specific screen.
    func viewController(_ viewController: RoverViewController, didDismissScreen screen: Screen, experience: Experience)
    
    /// Tells the delegate that the chid view controller for a given screen was viewed for a period of time. The child view controller keeps the viewing "session" alive if it is dismissed and presented again within a short period time. It also keeps the session alive if the app is put to the background and restored again within a short period of time. For this reason, this delegate method is only called after the child view controller is certain the session has ended. If the duration of time the screen was viewed is important you should use this method. However if you only need to be notified when the screen is initially presented, you are better suited to use the `viewController(_:, didPresentScreen:experience:)` method.
    func viewController(_ viewController: RoverViewController, didViewScreen screen: Screen, experience: Experience, duration: Double)
    
    /// Tells the delegate that a `UIView` representing a specific block somewhere within the view controller's hierarchy was tapped by the user.
    func viewController(_ viewController: RoverViewController, didTapBlock block: Block, screen: Screen, experience: Experience)
}

// Default "no-op" implementations to make all delegate methods optional.
extension RoverViewControllerDelegate {
    public func viewController(_ viewController: RoverViewController, didPresentExperience experience: Experience) { }
    public func viewController(_ viewController: RoverViewController, didDismissExperience experience: Experience) { }
    public func viewController(_ viewController: RoverViewController, didViewExperience experience: Experience, duration: Double) { }
    public func viewController(_ viewController: RoverViewController, didPresentScreen screen: Screen, experience: Experience) { }
    public func viewController(_ viewController: RoverViewController, didDismissScreen screen: Screen, experience: Experience) { }
    public func viewController(_ viewController: RoverViewController, didViewScreen screen: Screen, experience: Experience, duration: Double) { }
    public func viewController(_ viewController: RoverViewController, didTapBlock block: Block, screen: Screen, experience: Experience) { }
}

/// Either present or embed this view in a container to display a Rover experience.  Make sure you set Rover.accountToken first!
open class RoverViewController: UIViewController {    
    public let identifier: ExperienceIdentifier
    public let campaignID: String?
    
    /// An optional delegate that will be notified when certain experience "events" occur. E.g. when a screen is displayed or a block is tapped.
    public weak var delegate: RoverViewControllerDelegate?
    
    open private(set) lazy var urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    open private(set) lazy var httpClient = HTTPClient(session: urlSession) {
        AuthContext(
            accountToken: accountToken,
            endpoint: URL(string: "https://api.rover.io/graphql")!
        )
    }
    
    open private(set) lazy var experienceStore = ExperienceStoreService(
        client: self.httpClient
    )
    
    open private(set) lazy var imageStore = ImageStoreService(session: urlSession)
    
    open private(set) lazy var sessionController = SessionController(keepAliveTime: 10)
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.children.first
    }
    
    open var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.color = UIColor.gray
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    
    open var cancelButton: UIButton = {
        let cancelButton = UIButton(type: .custom)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.darkText, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        return cancelButton
    }()
    
    init(identifier: ExperienceIdentifier, campaignID: String? = nil) {
        self.identifier = identifier
        self.campaignID = campaignID
        super.init(nibName: nil, bundle: nil)
        
        Analytics.shared.enable()
        
        configureView()
        layoutActivityIndicator()
        layoutCancelButton()
    }
    
    public convenience init(experienceID: String, campaignID: String? = nil) {
        self.init(identifier: .experienceID(id: experienceID), campaignID: campaignID)
    }
    
    public convenience init(experienceURL: URL, campaignID: String? = nil) {
        self.init(identifier: .experienceURL(url: experienceURL), campaignID: campaignID)
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        fetchExperience()
    }
    
    open func configureView() {
        view.backgroundColor = UIColor.white
    }
    
    open func layoutActivityIndicator() {
        view.addSubview(activityIndicator)
        
        if #available(iOS 11.0, *) {
            let layoutGuide = view.safeAreaLayoutGuide
            activityIndicator.centerXAnchor.constraint(equalTo: layoutGuide.centerXAnchor).isActive = true
            activityIndicator.centerYAnchor.constraint(equalTo: layoutGuide.centerYAnchor).isActive = true
        } else {
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        }
    }
    
    open func layoutCancelButton() {
        view.addSubview(cancelButton)
        
        cancelButton.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor).isActive = true
        cancelButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8).isActive = true
    }
    
    @objc
    open func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    open func fetchExperience() {
        startLoading()
        
        experienceStore.fetchExperience(for: identifier) { [weak self] result in
            // If the user cancels loading, the view controller may have been dismissed and garbage collected before the fetch completes
            
            guard let container = self else {
                return
            }
            
            DispatchQueue.main.async {
                container.stopLoading()
                
                switch result {
                case let .error(error, shouldRetry):
                    container.present(error: error, shouldRetry: shouldRetry)
                case let .success(experience):
                    container.didFetchExperience(experience)
                }
            }
        }
    }
    
    // MARK: View Controller Factories
    
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
            imageStore: imageStore,
            sessionController: sessionController,
            viewControllerProvider: { (experience: Experience, screen: Screen) in
                self.screenViewController(experience: experience, screen: screen)
            },
            presentWebsite: { (url: URL, sourceViewController: UIViewController) in
                self.presentWebsite(sourceViewController: sourceViewController, url: url)
            }
        )
    }

    open func navigationController(experience: Experience) -> NavigationController {
        let homeScreenViewController = screenViewController(experience: experience, screen: experience.homeScreen)
        return NavigationController(
            sessionController: sessionController,
            homeScreenViewController: homeScreenViewController,
            experience: experience,
            campaignID: self.campaignID
        )
    }
    
    open func didFetchExperience(_ experience: Experience) {
        let viewController = self.navigationController(
            experience: experience
        )
        
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    var cancelButtonTimer: Timer?
    
    open func showCancelButton() {
        if let timer = cancelButtonTimer {
            timer.invalidate()
        }
        
        cancelButton.isHidden = true
        cancelButtonTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(3), repeats: false) { [weak self] _ in
            self?.cancelButtonTimer = nil
            self?.cancelButton.isHidden = false
        }
    }
    
    open func hideCancelButton() {
        if let timer = cancelButtonTimer {
            timer.invalidate()
        }
        
        cancelButton.isHidden = true
    }
    
    open func startLoading() {
        showCancelButton()
        activityIndicator.startAnimating()
    }
    
    open func stopLoading() {
        hideCancelButton()
        activityIndicator.stopAnimating()
    }
    
    open func present(error: Error?, shouldRetry: Bool) {
        let alertController: UIAlertController
        
        if shouldRetry {
            alertController = UIAlertController(title: "Error", message: "Failed to load experience", preferredStyle: UIAlertController.Style.alert)
            let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
            let retry = UIAlertAction(title: "Try Again", style: UIAlertAction.Style.default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.fetchExperience()
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
}

//
//  ExperienceContainer.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-02-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit
import os

open class ExperienceContainer: UIViewController {
    public let identifier: ExperienceIdentifier
    public let store: ExperienceStore
    
    public typealias ViewControllerProvider = (Experience) -> UIViewController?
    public let viewControllerProvider: ViewControllerProvider
    
    #if swift(>=4.2)
    open override var childForStatusBarStyle: UIViewController? {
        return self.children.first
    }
    #else
    open override var childViewControllerForStatusBarStyle: UIViewController? {
        return self.childViewControllers.first
    }
    #endif
    
    open var activityIndicator: UIActivityIndicatorView = {
        #if swift(>=4.2)
        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        #else
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        #endif
        
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
    
    public init(identifier: ExperienceIdentifier, store: ExperienceStore, viewControllerProvider: @escaping ViewControllerProvider) {
        self.store = store
        self.identifier = identifier
        self.viewControllerProvider = viewControllerProvider
        super.init(nibName: nil, bundle: nil)
        configureView()
        layoutActivityIndicator()
        layoutCancelButton()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
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
    
    @objc open func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    open func fetchExperience() {
        startLoading()
        
        let experienceId: String
        switch identifier {
        case .experienceID(let id):
            experienceId = id
        default:
            os_log("Unsupported Experience ID type. ExperienceID is (possibly) deprecated.", log: .ui, type: .error)
            return
        }
        
        guard let experience = store.get(byID: experienceId) else {
            return
        }
        
        didFetchExperience(experience)
    }
    
    open func didFetchExperience(_ experience: Experience) {
        guard let viewController = viewControllerProvider(experience) else {
            return
        }
        
        #if swift(>=4.2)
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        #else
        addChildViewController(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
        #endif
        
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
            #if swift(>=4.2)
            alertController = UIAlertController(title: "Error", message: "Failed to load experience", preferredStyle: UIAlertController.Style.alert)
            let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            })
            let retry = UIAlertAction(title: "Try Again", style: UIAlertAction.Style.default, handler: { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.fetchExperience()
            })
            #else
            alertController = UIAlertController(title: "Error", message: "Failed to load experience", preferredStyle: UIAlertControllerStyle.alert)
            let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            })
            let retry = UIAlertAction(title: "Try Again", style: UIAlertActionStyle.default, handler: { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.fetchExperience()
            })
            #endif
            
            alertController.addAction(cancel)
            alertController.addAction(retry)
        } else {
            #if swift(>=4.2)
            alertController = UIAlertController(title: "Error", message: "Something went wrong", preferredStyle: UIAlertController.Style.alert)
            let ok = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: { _ in
                alertController.dismiss(animated: false, completion: nil)
                self.dismiss(animated: true, completion: nil)
            })
            #else
            alertController = UIAlertController(title: "Error", message: "Something went wrong", preferredStyle: UIAlertControllerStyle.alert)
            let ok = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { _ in
                alertController.dismiss(animated: false, completion: nil)
                self.dismiss(animated: true, completion: nil)
            })
            #endif
            
            alertController.addAction(ok)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
}

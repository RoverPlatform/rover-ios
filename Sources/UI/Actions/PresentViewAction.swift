//
//  PresentViewAction.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

open class PresentViewAction: Action {
    public var viewControllerToPresent: UIViewController
    public var animated: Bool
    
    public init(viewControllerToPresent: UIViewController, animated: Bool) {
        self.animated = animated
        self.viewControllerToPresent = viewControllerToPresent
        super.init()
        name = "Present View"
    }
    
    override open func execute() {
        // TODO: this ought to be refactored into multiple methods.
        // swiftlint:disable:next closure_body_length
        DispatchQueue.main.async { [weak self] in
            guard let _self = self else {
                return
            }
            
            let viewControllerToPresent = _self.viewControllerToPresent
            
            // Check if `viewControllerToPresent` is already presented
            
            if viewControllerToPresent.isBeingPresented || viewControllerToPresent.presentingViewController != nil {
                _self.finish()
                return
            }
            
            // If `viewControllerToPresent` is embedded in a `UITabBarController`, set the active tab
            
            if let tabBarController = viewControllerToPresent.tabBarController {
                tabBarController.selectedViewController = viewControllerToPresent
                _self.finish()
                return
            }
            
            // Presenting `viewControllerToPresent` inside a container other than `UITabBarController` is not supported at this time
            
            if viewControllerToPresent.parent != nil {
                os_log("Failed to present viewControllerToPresent - already presented in an unsupported container", log: .dispatching, type: .default)
                _self.finish()
                return
            }
            
            // The `viewControllerToPresent` is not part of the display hierarchy – present it modally
            
            // Find the currently visible view controller and use it as the presenter
            
            guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
                os_log("Failed to present viewControllerToPresent - rootViewController not found", log: .dispatching, type: .error)
                _self.finish()
                return
            }
            
            var findVisibleViewController: ((UIViewController) -> UIViewController?)?
            findVisibleViewController = { viewController in
                if let presentedViewController = viewController.presentedViewController {
                    return findVisibleViewController?(presentedViewController)
                }
                
                if let navigationController = viewController as? UINavigationController {
                    return navigationController.visibleViewController
                }
                
                if let tabBarController = viewController as? UITabBarController {
                    return tabBarController.selectedViewController
                }
                
                return viewController
            }
            
            guard let visibleViewController = findVisibleViewController?(rootViewController) else {
                os_log("Failed to present `viewControllerToPresent` - visible view controller not found", log: .dispatching, type: .error)
                _self.finish()
                return
            }
            
            visibleViewController.present(viewControllerToPresent, animated: _self.animated) {
                _self.finish()
            }
        }
    }
}

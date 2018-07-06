//
//  PresentViewAction.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

open class PresentViewAction: Action {
    public let logger: Logger
    
    public var viewControllerToPresent: UIViewController
    public var animated: Bool
    
    public init(viewControllerToPresent: UIViewController, animated: Bool, logger: Logger) {
        self.animated = animated
        self.logger = logger
        self.viewControllerToPresent = viewControllerToPresent
        super.init()
        name = "Present View"
    }
    
    override open func execute() {
        DispatchQueue.main.async { [weak self] in
            guard let operation = self else {
                return
            }
            
            let logger = operation.logger
            let viewControllerToPresent = operation.viewControllerToPresent
            
            // Check if `viewControllerToPresent` is already presented
            
            if viewControllerToPresent.isBeingPresented || viewControllerToPresent.presentingViewController != nil {
                operation.finish()
                return
            }
            
            // If `viewControllerToPresent` is embedded in a `UITabBarController`, set the active tab
            
            if let tabBarController = viewControllerToPresent.tabBarController {
                tabBarController.selectedViewController = viewControllerToPresent
                operation.finish()
                return
            }
            
            // Presenting `viewControllerToPresent` inside a container other than `UITabBarController` is not supported at this time
            
            if viewControllerToPresent.parent != nil {
                logger.warn("Failed to present viewControllerToPresent - already presented in an unsupported container")
                operation.finish()
                return
            }
            
            // The `viewControllerToPresent` is not part of the display hierarchy – present it modally
            
            // Find the currently visible view controller and use it as the presenter
            
            guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
                logger.error("Failed to present viewControllerToPresent - rootViewController not found")
                operation.finish()
                return
            }
            
            var findVisibleViewController: ((UIViewController) -> UIViewController?)!
            findVisibleViewController = { viewController in
                if let presentedViewController = viewController.presentedViewController {
                    return findVisibleViewController(presentedViewController)
                }
                
                if let navigationController = viewController as? UINavigationController {
                    return navigationController.visibleViewController
                }
                
                if let tabBarController = viewController as? UITabBarController {
                    return tabBarController.selectedViewController
                }
                
                return viewController
            }
            
            guard let visibleViewController = findVisibleViewController(rootViewController) else {
                logger.error("Failed to present `viewControllerToPresent` - visible view controller not found")
                operation.finish()
                return
            }
            
            visibleViewController.present(viewControllerToPresent, animated: operation.animated) {
                operation.finish()
            }
        }
    }
}

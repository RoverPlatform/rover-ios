//
//  UIApplication.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-04-29.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os
import UIKit

extension UIApplication {
    public func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        // Check if `viewControllerToPresent` is already presented
        
        if viewControllerToPresent.isBeingPresented || viewControllerToPresent.presentingViewController != nil {
            completion?()
            return
        }
        
        // If `viewControllerToPresent` is embedded in a `UITabBarController`, set the active tab
        
        if let tabBarController = viewControllerToPresent.tabBarController {
            tabBarController.selectedViewController = viewControllerToPresent
            completion?()
            return
        }
        
        // Presenting `viewControllerToPresent` inside a container other than `UITabBarController` is not supported at this time
        
        if viewControllerToPresent.parent != nil {
            os_log("Failed to present viewControllerToPresent - already presented in an unsupported container", log: .rover, type: .default)
            completion?()
            return
        }
        
        // The `viewControllerToPresent` is not part of the display hierarchy – present it modally
        
        // Find the currently visible view controller and use it as the presenter
        
        guard let rootViewController = self.keyWindow?.rootViewController else {
            os_log("Failed to present viewControllerToPresent - rootViewController not found", log: .rover, type: .error)
            completion?()
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
            os_log("Failed to present `viewControllerToPresent` - visible view controller not found", log: .rover, type: .error)
            completion?()
            return
        }
        
        visibleViewController.present(viewControllerToPresent, animated: flag) {
            completion?()
        }
    }
}

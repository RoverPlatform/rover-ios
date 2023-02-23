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

import os.log
import UIKit

import RoverFoundation

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

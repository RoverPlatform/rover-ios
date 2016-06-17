//
//  NavigationController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-06-06.
//
//

import UIKit

protocol ModalViewControllerDelegate: class {
    func didDismissModalViewController(viewController: ModalViewController)
}

class ModalViewController: UINavigationController {
    
    weak var modalDelegate: ModalViewControllerDelegate?
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        
        addCloseButtonToViewController(rootViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func pushViewController(viewController: UIViewController, animated: Bool) {
        addCloseButtonToViewController(viewController)
        super.pushViewController(viewController, animated: animated)
    }
    
    override func dismissViewControllerAnimated(flag: Bool, completion: (() -> Void)?) {
        super.dismissViewControllerAnimated(flag, completion: completion)
        modalDelegate?.didDismissModalViewController(self)
    }

    func dismissViewController() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func addCloseButtonToViewController(viewController: UIViewController) {
        self.topViewController?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .Plain, target: self, action: #selector(dismissViewController))
    }
}

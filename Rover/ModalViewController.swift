//
//  NavigationController.swift
//  Pods
//
//  Created by Ata Namvari on 2016-06-06.
//
//

import UIKit

protocol ModalViewControllerDelegate: class {
    func didDismissModalViewController(_ viewController: ModalViewController)
}

open class ModalViewController: UINavigationController {
    
    weak var modalDelegate: ModalViewControllerDelegate?
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        
        addCloseButtonToViewController(rootViewController)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override open func pushViewController(_ viewController: UIViewController, animated: Bool) {
        addCloseButtonToViewController(viewController)
        super.pushViewController(viewController, animated: animated)
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        super.dismiss(animated: flag, completion: completion)
        modalDelegate?.didDismissModalViewController(self)
    }

    @objc func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func addCloseButtonToViewController(_ viewController: UIViewController) {
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(dismissViewController))
    }
}

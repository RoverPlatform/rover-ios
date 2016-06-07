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
    
    override func dismissViewControllerAnimated(flag: Bool, completion: (() -> Void)?) {
        super.dismissViewControllerAnimated(flag, completion: completion)
        modalDelegate?.didDismissModalViewController(self)
    }

}

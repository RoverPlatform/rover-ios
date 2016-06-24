//
//  TabBarController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didUpdateAccount), name: RoverAccountUpdatedNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        presentSignInIfNeeded()
    }
    
    func didUpdateAccount(note: NSNotification) {
        presentSignInIfNeeded()
    }
    
    func presentSignInIfNeeded() {
        if AccountManager.currentAccount == nil {
            performSegueWithIdentifier("LoginSegue", sender: nil)
        }
    }
}

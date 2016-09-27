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
        
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateAccount), name: NSNotification.Name(rawValue: RoverAccountUpdatedNotification), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        presentSignInIfNeeded()
    }
    
    func didUpdateAccount(_ note: Notification) {
        presentSignInIfNeeded()
    }
    
    func presentSignInIfNeeded() {
        if AccountManager.currentAccount == nil {
            performSegue(withIdentifier: "LoginSegue", sender: nil)
        }
    }
}

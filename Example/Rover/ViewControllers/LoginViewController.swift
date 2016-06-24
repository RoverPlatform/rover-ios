//
//  LoginViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(accountUpdated), name: RoverAccountUpdatedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didFailToSignIn), name: RoverAccountErrorNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didFailToSignIn), name: RoverSessionErrorNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillHide), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @IBAction func didPressSignIn(sender: UIButton) {
        // Show Activity Indicator
        
        let session = Session(authToken: nil, email: emailTextField.text, password: passwordTextField.text, accountId: nil)
        SessionManager.startNewSession(session)
    }
    
    func accountUpdated(note: NSNotification) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func didFailToSignIn(note: NSNotification) {
        // Hide Activity Indicator
        
        var message: String
        if note.name == RoverSessionErrorNotification {
            message = "Invalid email or password."
        } else {
            message = "Could not retrieve account information. Please try again."
        }
        
        let alert = UIAlertController(title: "Error Signing In", message: message, preferredStyle: .Alert)
        let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(action)
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func keyboardWillShow(note: NSNotification) {
        guard let keyboardRect = note.userInfo?[UIKeyboardFrameEndUserInfoKey]?.CGRectValue()
            where view.bounds.height < 667 else { return }
        
        scrollViewBottomConstraint.constant = keyboardRect.height
        view.layoutIfNeeded()
    }
    
    func keyboardWillHide(note: NSNotification) {
        scrollViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }
}
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(accountUpdated), name: NSNotification.Name(rawValue: RoverAccountUpdatedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didFailToSignIn), name: NSNotification.Name(rawValue: RoverAccountErrorNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didFailToSignIn), name: NSNotification.Name(rawValue: RoverSessionErrorNotification), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func didPressSignIn(_ sender: UIButton) {
        // Show Activity Indicator
        
        let session = Session(authToken: nil, email: emailTextField.text, password: passwordTextField.text, accountId: nil)
        SessionManager.startNewSession(session)
    }
    
    func accountUpdated(_ note: Notification) {
        dismiss(animated: true, completion: nil)
    }
    
    func didFailToSignIn(_ note: Notification) {
        // Hide Activity Indicator
        
        var message: String
        if note.name.rawValue == RoverSessionErrorNotification {
            message = "Invalid email or password."
        } else {
            message = "Could not retrieve account information. Please try again."
        }
        
        let alert = UIAlertController(title: "Error Signing In", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    func keyboardWillShow(_ note: Notification) {
        guard let keyboardRect = ((note as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
            , view.bounds.height < 667 else { return }
        
        scrollViewBottomConstraint.constant = keyboardRect.height
        view.layoutIfNeeded()
    }
    
    func keyboardWillHide(_ note: Notification) {
        scrollViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }
}

//
//  ProfileViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-04.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let UserDidSignOutNotification = "UserDidSignOutNotification"

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var identifierField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var tagsField: UITextField!
    @IBOutlet weak var genderField: UITextField!
    @IBOutlet weak var ageField: UITextField!
    @IBOutlet weak var traitsTable: UITableView!
    
    enum TraitType: String {
        case Number = "Number"
        case String = "String"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let customer = Rover.customer
        
        identifierField.text = customer.identifier
        //nameField.text = customer.name
        emailField.text = customer.email
        phoneField.text = customer.phone
        genderField.text = customer.gender
        ageField.text = String(describing: customer.age)
        tagsField.text = customer.tags?.joined(separator: ",")
        
        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.didShowKeyboard(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        
        let exp = ExperienceViewController(identifier: "57b74e723f1a36002771f59b")
        present(exp, animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func didShowKeyboard(_ note: Notification) {
        //navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(ProfileViewController.didFinishEditing))
    }
    
    func didFinishEditing() {
        self.view.endEditing(true)
        navigationItem.rightBarButtonItem = nil
    }

    // MARK: Actions
    
    @IBAction func didPressAddTrait(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Select type of trait", preferredStyle: .actionSheet)
        let integerAction = UIAlertAction(title: "Number", style: .default, handler: addTraitAction(.Number))
        let stringAction = UIAlertAction(title: "String", style: .default, handler: addTraitAction(.String))
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(integerAction)
        alert.addAction(stringAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func textFieldDidFinishEditing(_ sender: UITextField) {
        let customer = Rover.customer
        customer.identifier = self.identifierField.text
        
        let name = self.nameField.text?.components(separatedBy: " ")
        if name?.count > 0 {
            customer.firstName = name?[0]
        }
        if name?.count > 1 {
            customer.lastName = name?[1]
        }
        
        customer.email = self.emailField.text
        customer.phone = self.phoneField.text
        customer.gender = self.genderField.text
        customer.age = Int(self.ageField.text ?? "0")
        customer.tags = self.tagsField.text?.components(separatedBy: ",")
        customer.save()
    }
    
    
    @IBAction func didPressSignOutButton(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
            Rover.stopMonitoring()
            AccountManager.clearCurrentAccount()
            SessionManager.clearCurrentSession()
            NotificationCenter.default.post(name: Notification.Name(rawValue: UserDidSignOutNotification), object: nil)
        }
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Helper
    
    func addTraitAction(_ type: TraitType) -> ((UIAlertAction) -> Void) {
        let customer = Rover.customer
        return { action in
            let keyAlert = UIAlertController(title: "New Trait", message: "Enter a key for this trait", preferredStyle: .alert)
            var keyTextField: UITextField?
            keyAlert.addTextField { textField in
                keyTextField = textField
            }
            let addAction = UIAlertAction(title: "Add", style: .default) { action in
                guard let keyText = keyTextField?.text else { return }
                
                switch type {
                case .Number:
                    customer.traits[keyText] = 0.0
                case .String:
                    customer.traits[keyText] = ""
                }
                
                customer.save()
                
                self.traitsTable.reloadData()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            keyAlert.addAction(addAction)
            keyAlert.addAction(cancelAction)
            
            self.present(keyAlert, animated: true, completion: nil)
        }
    }

}

extension ProfileViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Rover.customer.traits.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Traits"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let customer = Rover.customer
        let traitKeys = Array(customer.traits.keys)
        let traitLabel = traitKeys[(indexPath as NSIndexPath).row]
        let traitValue = customer.traits[traitLabel]
        
        var cell: TraitTableViewCell
        
        switch traitValue {
        case is String:
            cell = tableView.dequeueReusableCell(withIdentifier: "StringTraitCellIdentifier", for: indexPath) as! TraitTableViewCell
            cell.label.text = traitLabel
            cell.textField.text = traitValue as? String
            cell.delegate = self
            break
        case is Double:
            cell = tableView.dequeueReusableCell(withIdentifier: "NumberTraitCellIdentifier", for: indexPath) as! TraitTableViewCell
            cell.label.text = traitLabel
            cell.textField.text = String(traitValue as! Double)
            cell.delegate = self
            break
        default:
            fatalError("Unknown type of trait")
        }
        
        return cell
    }
    
}

extension ProfileViewController: TraitTableViewCellDelegate {
    
    func traitTableViewCell(_ cell: TraitTableViewCell, didChangeValue value: String?) {
        guard let key = cell.label.text else { return }
        let customer = Rover.customer
        switch customer.traits[key] {
        case is Double:
            customer.traits[key] = Double(value ?? "0")
        default:
            customer.traits[key] = value
        }
        
        customer.save()
    }
}

extension ProfileViewController: UITableViewDelegate {
    
    @objc(tableView:commitEditingStyle:forRowAtIndexPath:)
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let customer = Rover.customer
        let traitKey = Array(customer.traits.keys)[(indexPath as NSIndexPath).row]
        
        customer.traits.removeValue(forKey: traitKey)
        traitsTable.deleteRows(at: [indexPath], with: .automatic)
        
        customer.save()
    }
}


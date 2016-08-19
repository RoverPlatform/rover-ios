//
//  ProfileViewController.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-04.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import Rover

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
        ageField.text = String(customer.age)
        tagsField.text = customer.tags?.joinWithSeparator(",")
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ProfileViewController.didShowKeyboard(_:)), name: UIKeyboardDidShowNotification, object: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didShowKeyboard(note: NSNotification) {
        //navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .Done, target: self, action: #selector(ProfileViewController.didFinishEditing))
    }
    
    func didFinishEditing() {
        self.view.endEditing(true)
        navigationItem.rightBarButtonItem = nil
    }

    // MARK: Actions
    
    @IBAction func didPressAddTrait(sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Select type of trait", preferredStyle: .ActionSheet)
        let integerAction = UIAlertAction(title: "Number", style: .Default, handler: addTraitAction(.Number))
        let stringAction = UIAlertAction(title: "String", style: .Default, handler: addTraitAction(.String))
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        alert.addAction(integerAction)
        alert.addAction(stringAction)
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion: nil)
    }
    
    @IBAction func textFieldDidFinishEditing(sender: UITextField) {
        let customer = Rover.customer
        customer.identifier = self.identifierField.text
        
        let name = self.nameField.text?.componentsSeparatedByString(" ")
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
        customer.tags = self.tagsField.text?.componentsSeparatedByString(",")
        customer.save()
    }
    
    
    @IBAction func didPressSignOutButton(sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .Alert)
        let yesAction = UIAlertAction(title: "Yes", style: .Default) { _ in
            Rover.stopMonitoring()
            AccountManager.clearCurrentAccount()
            SessionManager.clearCurrentSession()
            NSNotificationCenter.defaultCenter().postNotificationName(UserDidSignOutNotification, object: nil)
        }
        let noAction = UIAlertAction(title: "No", style: .Cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: Helper
    
    func addTraitAction(type: TraitType) -> (UIAlertAction -> Void) {
        let customer = Rover.customer
        return { action in
            let keyAlert = UIAlertController(title: "New Trait", message: "Enter a key for this trait", preferredStyle: .Alert)
            var keyTextField: UITextField?
            keyAlert.addTextFieldWithConfigurationHandler { textField in
                keyTextField = textField
            }
            let addAction = UIAlertAction(title: "Add", style: .Default) { action in
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
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            keyAlert.addAction(addAction)
            keyAlert.addAction(cancelAction)
            
            self.presentViewController(keyAlert, animated: true, completion: nil)
        }
    }

}

extension ProfileViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Rover.customer.traits.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Traits"
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let customer = Rover.customer
        let traitKeys = Array(customer.traits.keys)
        let traitLabel = traitKeys[indexPath.row]
        let traitValue = customer.traits[traitLabel]
        
        var cell: TraitTableViewCell
        
        switch traitValue {
        case is String:
            cell = tableView.dequeueReusableCellWithIdentifier("StringTraitCellIdentifier", forIndexPath: indexPath) as! TraitTableViewCell
            cell.label.text = traitLabel
            cell.textField.text = traitValue as? String
            cell.delegate = self
            break
        case is Double:
            cell = tableView.dequeueReusableCellWithIdentifier("NumberTraitCellIdentifier", forIndexPath: indexPath) as! TraitTableViewCell
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
    
    func traitTableViewCell(cell: TraitTableViewCell, didChangeValue value: String?) {
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
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard editingStyle == .Delete else { return }
        let customer = Rover.customer
        let traitKey = Array(customer.traits.keys)[indexPath.row]
        
        customer.traits.removeValueForKey(traitKey)
        traitsTable.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        
        customer.save()
    }
}


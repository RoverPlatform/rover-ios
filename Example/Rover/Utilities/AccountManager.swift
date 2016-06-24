//
//  AccountManager.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import Rover

let RoverAccountUpdatedNotification = "RoverAccountUpdatedNotification"
let RoverAccountErrorNotification = "RoverAccountErrorNotification"

class AccountManager {
    
    static let sharedManager = AccountManager()
    
    private var _currentAcount: Account? {
        didSet {
            NSUserDefaults.standardUserDefaults().setObject(_currentAcount?.applicationToken, forKey: "ROVER_APPLICATION_TOKEN")
        }
    }
    
    static var currentAccount: Account? {
        if sharedManager._currentAcount != nil {
            return sharedManager._currentAcount
        }
        
        if let applicationToken = NSUserDefaults.standardUserDefaults().stringForKey("ROVER_APPLICATION_TOKEN") {
            sharedManager._currentAcount = Account(applicationToken: applicationToken)
        }
        return sharedManager._currentAcount
    }
    
    var operationQueue = NSOperationQueue()
    
    private init() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didCreateNewSession), name: RoverNewSessionNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func didCreateNewSession(note: NSNotification) {
        
        let mappingOperation = MappingOperation { (account: Account) in
            self._currentAcount = account
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(RoverAccountUpdatedNotification, object: nil)
            }
        }
        
        let networkOperation = NetworkOperation(mutableUrlRequest: APIRouter.Accounts.urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
            
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().postNotificationName(RoverAccountErrorNotification, object: nil)
                }
            }
        }
        
        mappingOperation.addDependency(networkOperation)
        
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
    class func clearCurrentAccount() {
        sharedManager._currentAcount = nil
        NSNotificationCenter.defaultCenter().postNotificationName(RoverAccountUpdatedNotification, object: nil)
    }
}

extension Account : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Account? {
        guard let type = JSON["type"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            token = attributes["token"] as? String
            where type == "accounts" else { return nil }
        
        return Account(applicationToken: token)
    }
}

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
    
    fileprivate var _currentAcount: Account? {
        didSet {
            UserDefaults.standard.set(_currentAcount?.applicationToken, forKey: "ROVER_APPLICATION_TOKEN")
        }
    }
    
    static var currentAccount: Account? {
        if sharedManager._currentAcount != nil {
            return sharedManager._currentAcount
        }
        
        if let applicationToken = UserDefaults.standard.string(forKey: "ROVER_APPLICATION_TOKEN") {
            sharedManager._currentAcount = Account(applicationToken: applicationToken)
        }
        return sharedManager._currentAcount
    }
    
    var operationQueue = OperationQueue()
    
    fileprivate init() {
        NotificationCenter.default.addObserver(self, selector: #selector(didCreateNewSession), name: NSNotification.Name(rawValue: RoverNewSessionNotification), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func didCreateNewSession(_ note: Notification) {
        
        let mappingOperation = MappingOperation { (account: Account) in
            self._currentAcount = account
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: RoverAccountUpdatedNotification), object: nil)
            }
        }
        
        let networkOperation = NetworkOperation(urlRequest: APIRouter.accounts.urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
            
            if error != nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: RoverAccountErrorNotification), object: nil)
                }
            }
        }
        
        mappingOperation.addDependency(networkOperation)
        
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
    class func clearCurrentAccount() {
        sharedManager._currentAcount = nil
        NotificationCenter.default.post(name: Notification.Name(rawValue: RoverAccountUpdatedNotification), object: nil)
    }
}

extension Account : Mappable {
    static func instance(_ JSON: [String : Any], included: [String : Any]?) -> Account? {
        guard let type = JSON["type"] as? String,
            let attributes = JSON["attributes"] as? [String: Any],
            let token = attributes["token"] as? String
            , type == "accounts" else { return nil }
        
        return Account(applicationToken: token)
    }
}

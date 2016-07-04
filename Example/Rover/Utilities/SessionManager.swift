//
//  SessionManager.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import Rover

let RoverNewSessionNotification = "RoverNewSessionNotification"
let RoverSessionErrorNotification = "RoverSessionErrorNotification"

class SessionManager {
    
    static let sharedManager = SessionManager()
    
    private static var _currentSession: Session? {
        didSet {
            NSUserDefaults.standardUserDefaults().setObject(_currentSession?.authToken, forKey: "ROVER_AUTH_TOKEN")
            NSUserDefaults.standardUserDefaults().setObject(_currentSession?.accountId, forKey: "ROVER_ACCOUNT_ID")
        }
    }
    static var currentSession: Session? {
        if _currentSession != nil {
            return _currentSession
        }
        
        if let authToken = NSUserDefaults.standardUserDefaults().stringForKey("ROVER_AUTH_TOKEN"),
         let accountId = NSUserDefaults.standardUserDefaults().stringForKey("ROVER_ACCOUNT_ID") {
            _currentSession = Session(authToken: authToken, email: nil, password: nil, accountId: accountId)
        }
        return _currentSession
    }
    
    var operationQueue = NSOperationQueue()
    
    class func startNewSession(session: Session) {
        let mappingOperation = MappingOperation { (session: Session) in
            SessionManager._currentSession = session
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(RoverNewSessionNotification, object: nil, userInfo: ["token": session.authToken ?? ""])
            }
        }
        
        let networkOperation = NetworkOperation(mutableUrlRequest: APIRouter.SessionSignIn.urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
            
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().postNotificationName(RoverSessionErrorNotification, object: nil, userInfo: nil)
                }
            }
        }
        
        let serializeOperation = SerializingOperation(model: session) {
            [unowned networkOperation]
            JSON in
            
            networkOperation.payload = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        networkOperation.addDependency(serializeOperation)
        
        sharedManager.operationQueue.addOperation(serializeOperation)
        sharedManager.operationQueue.addOperation(networkOperation)
        sharedManager.operationQueue.addOperation(mappingOperation)
    }
    
    class func clearCurrentSession() {
        _currentSession = nil
    }
}

extension Session : Serializable {
    func serialize() -> [String : AnyObject] {
        return [
            "data": [
                "type": "sessions",
                "attributes": [
                    "email": email ?? "",
                    "password": password ?? ""
                ]
            ]
        ]
    }
}

extension Session : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Session? {
        guard let type = JSON["type"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            token = attributes["token"] as? String,
            relationships = JSON["relationships"] as? [String: AnyObject],
            accountData = relationships["account"] as? [String: AnyObject],
            accountAttributes = accountData["data"] as? [String: AnyObject],
            accountId = accountAttributes["id"] as? String
            where type == "sessions" else { return nil }
        
        let email = attributes["email"] as? String
        
        return Session(authToken: token, email: email, password: nil, accountId: accountId)
    }
}
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
    
    fileprivate static var _currentSession: Session? {
        didSet {
            UserDefaults.standard.set(_currentSession?.authToken, forKey: "ROVER_AUTH_TOKEN")
            UserDefaults.standard.set(_currentSession?.accountId, forKey: "ROVER_ACCOUNT_ID")
        }
    }
    static var currentSession: Session? {
        if _currentSession != nil {
            return _currentSession
        }
        
        if let authToken = UserDefaults.standard.string(forKey: "ROVER_AUTH_TOKEN"),
         let accountId = UserDefaults.standard.string(forKey: "ROVER_ACCOUNT_ID") {
            _currentSession = Session(authToken: authToken, email: nil, password: nil, accountId: accountId)
        }
        return _currentSession
    }
    
    var operationQueue = OperationQueue()
    
    class func startNewSession(_ session: Session) {
        let mappingOperation = MappingOperation { (session: Session) in
            SessionManager._currentSession = session
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: RoverNewSessionNotification), object: nil, userInfo: ["token": session.authToken ?? ""])
            }
        }
        
        let networkOperation = NetworkOperation(mutableUrlRequest: APIRouter.sessionSignIn.urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            mappingOperation.json = JSON
            
            if error != nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: RoverSessionErrorNotification), object: nil, userInfo: nil)
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
    func serialize() -> [String : Any] {
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
    static func instance(_ JSON: [String : Any], included: [String : Any]?) -> Session? {
        guard let type = JSON["type"] as? String,
            let attributes = JSON["attributes"] as? [String: Any],
            let token = attributes["token"] as? String,
            let relationships = JSON["relationships"] as? [String: Any],
            let accountData = relationships["account"] as? [String: Any],
            let accountAttributes = accountData["data"] as? [String: Any],
            let accountId = accountAttributes["id"] as? String
            , type == "sessions" else { return nil }
        
        let email = attributes["email"] as? String
        
        return Session(authToken: token, email: email, password: nil, accountId: accountId)
    }
}

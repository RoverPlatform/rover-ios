//
//  SessionControllerService.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public class SessionController {

    public func registerSession(identifier: String, sessionCompletedInfo: EventInfo) {
        // session duration will be added for us on the other end.
        var notification = Notification.init(from: sessionCompletedInfo, withName: "RoverSessionDidOpen")
        var userInfo: [AnyHashable: Any] = notification.userInfo ?? [AnyHashable: Any]()
        userInfo["sessionIdentifier"] = identifier
        notification.userInfo = userInfo
        NotificationCenter.default.post(notification)
    }
    
    public func unregisterSession(identifier: String) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "RoverSessionDidClose"),
            object: nil,
            userInfo: ["sessionIdentifier": identifier]
        )
    }
}


extension Notification {
    init(from info: EventInfo, withName name: String) {
        let name = Notification.Name(name)
        
        let userInfoAllFields: [String: Any?] = [
            "name": info.name,
            "namespace": info.namespace,
            "attributes": info.attributes
        ]
        
        // Clear out the nil values.
        let userInfo = userInfoAllFields.reduce([String:Any]()) { (userInfo, keyValue) in
            let (key, value) = keyValue
            if(value != nil) {
                return userInfo.merging([key: value!], uniquingKeysWith: { (a, b) in
                    // no duplicates
                    return a
                })
            } else {
                return userInfo
            }
        }
        
        self.init(name: name, object: nil, userInfo: userInfo)
    }
}

//
//  Router.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation

enum APIRouter {
    case SessionSignIn
    case Accounts
    
    var baseURL: NSURL {
        return NSURL(string: "https://api.rover.io/v1")!
    }
    
    var method: String {
        switch self {
        case .SessionSignIn:
            return "POST"
        default:
            return "GET"
        }
    }
    
    var url: NSURL {
        switch self {
        case .SessionSignIn:
            return baseURL.URLByAppendingPathComponent("sessions")
        case .Accounts:
            let accountId = SessionManager.currentSession?.accountId ?? ""
            return baseURL.URLByAppendingPathComponent("accounts/\(accountId)")
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let request = NSMutableURLRequest(URL: url)
        let token = SessionManager.currentSession?.authToken ?? ""
        request.HTTPMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
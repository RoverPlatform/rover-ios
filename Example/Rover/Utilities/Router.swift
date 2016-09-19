//
//  Router.swift
//  Rover
//
//  Created by Ata Namvari on 2016-06-23.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import Rover

enum APIRouter {
    case sessionSignIn
    case accounts
    
    var baseURL: URL {
        return URL(string: Router.baseURLString)!
    }
    
    var method: String {
        switch self {
        case .sessionSignIn:
            return "POST"
        default:
            return "GET"
        }
    }
    
    var url: URL {
        switch self {
        case .sessionSignIn:
            return baseURL.appendingPathComponent("sessions")
        case .accounts:
            let accountId = SessionManager.currentSession?.accountId ?? ""
            return baseURL.appendingPathComponent("accounts/\(accountId)")
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let request = NSMutableURLRequest(url: url)
        let token = SessionManager.currentSession?.authToken ?? ""
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

//
//  Router.swift
//  Pods
//
//  Created by Ata Namvari on 2016-04-28.
//
//

import Foundation

public enum Router {
    
    case Events
    case Inbox
    case DeleteMessage(Message)
    case PatchMessage(Message)
    case GetMessage(String)
    case GetLandingPage(Message)
    
    public static var baseURLString = "https://api.rover.io/v1"
    
    var method: String {
        switch self {
        case .Events:
            return "POST"
        case .DeleteMessage(_):
            return "DELETE"
        case .PatchMessage(_):
            return "PATCH"
        default:
            return "GET"
        }
    }
    
    var url: NSURL {
        switch self {
        case .Events:
            return NSURL(string: "\(Router.baseURLString)/events")!
        case .Inbox:
            return NSURL(string: "\(Router.baseURLString)/inbox")!
        case .DeleteMessage(let message):
            return NSURL(string: "\(Router.baseURLString)/inbox/\(message.identifier)")!
        case .PatchMessage(let message):
            return NSURL(string: "\(Router.baseURLString)/inbox/\(message.identifier)")!
        case .GetMessage(let id):
            return NSURL(string: "\(Router.baseURLString)/inbox/\(id)")!
        case .GetLandingPage(let message):
            return NSURL(string: "\(Router.baseURLString)/inbox/\(message.identifier)/landing-page")!
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let urlRequest = NSMutableURLRequest(URL: self.url)
        urlRequest.HTTPMethod = self.method
        urlRequest.setValue(Rover.sharedInstance?.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        urlRequest.setValue(UIDevice.currentDevice().identifierForVendor?.UUIDString ?? "[UNKNOWN]", forHTTPHeaderField: "X-Rover-Device-Id")
        return urlRequest
    }
}
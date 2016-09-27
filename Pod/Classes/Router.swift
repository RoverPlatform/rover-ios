//
//  Router.swift
//  Pods
//
//  Created by Ata Namvari on 2016-04-28.
//
//

import Foundation

public enum Router {
    
    case events
    case inbox
    case deleteMessage(Message)
    case patchMessage(Message)
    case getMessage(String)
    case getLandingPage(Message)
    case getExperience(String)
    
    public static var baseURLString = "http://api.rover.io/v1" //"https://api-development.rover.io/v1"
    
    var method: String {
        switch self {
        case .events:
            return "POST"
        case .deleteMessage(_):
            return "DELETE"
        case .patchMessage(_):
            return "PATCH"
        default:
            return "GET"
        }
    }
    
    var url: URL {
        switch self {
        case .events:
            return URL(string: "\(Router.baseURLString)/events")!
        case .inbox:
            return URL(string: "\(Router.baseURLString)/inbox")!
        case .deleteMessage(let message):
            return URL(string: "\(Router.baseURLString)/inbox/\(message.identifier)")!
        case .patchMessage(let message):
            return URL(string: "\(Router.baseURLString)/inbox/\(message.identifier)")!
        case .getMessage(let id):
            return URL(string: "\(Router.baseURLString)/inbox/\(id)")!
        case .getLandingPage(let message):
            return URL(string: "\(Router.baseURLString)/inbox/\(message.identifier)/landing-page")!
        case .getExperience(let identifier):
            return URL(string: "\(Router.baseURLString)/experiences/\(identifier)")!
        }
    }
    
    var urlRequest: URLRequest {
        var urlRequest = URLRequest(url: self.url)
        urlRequest.httpMethod = self.method
        urlRequest.setValue(Rover.sharedInstance?.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        urlRequest.setValue(UIDevice.current.identifierForVendor?.uuidString ?? "[UNKNOWN]", forHTTPHeaderField: "X-Rover-Device-Id")
        return urlRequest
    }
}

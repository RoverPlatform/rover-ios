//
//  NetworkOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation

public class NetworkOperation: ConcurrentOperation {
    
    var urlRequest: NSMutableURLRequest
    var urlSessionTask: NSURLSessionDataTask?
    public var payload: [String: AnyObject]?
    var completion: JSONCompletionBlock?
    
    private var payloadAsQuery: String {
        guard let payload = payload else { return "" }
        var params = [String]()
        for (key, value) in payload {
            params.append("\(key)=\(value)")
        }
        return params.joinWithSeparator("&")
    }
    
    private var _finished = false
    private var _executing = false
    
    public typealias JSONCompletionBlock = ([String: AnyObject]?, ErrorType?) -> Void
    
    required public init(mutableUrlRequest: NSMutableURLRequest, completion: JSONCompletionBlock?) {
        self.urlRequest = mutableUrlRequest
        self.completion = completion
        super.init()
    }
    
    convenience init(urlRequest: NSURLRequest, completion: JSONCompletionBlock?) {
        self.init(mutableUrlRequest: urlRequest.mutableCopy() as! NSMutableURLRequest, completion: completion)
    }
    
    convenience init(url: NSURL, method: String, completion: JSONCompletionBlock?) {
        let urlRequest = NSMutableURLRequest(URL: url)
        urlRequest.HTTPMethod = method
        
        self.init(mutableUrlRequest: urlRequest, completion: completion)
    }

    override func execute() {
        do {
            if let payload = payload {
                switch self.urlRequest.HTTPMethod {
                case "GET":
                    urlRequest.URL = NSURL(string: "\(urlRequest.URL?.absoluteString)?\(payloadAsQuery)")
                default:
                    urlRequest.HTTPBody = try NSJSONSerialization.dataWithJSONObject(payload, options: .PrettyPrinted)
                }
            }
            
            urlRequest.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        } catch {
            self.completion?(nil, error)
            rvLog("Error creating network request", data: error, level: .Error)
            finish()
            return
        }
        
        // TODO: maybe use KVO on URLSession like they do in AdvancedNSOperations example project
        
        let urlSessionTask = NSURLSession.sharedSession().dataTaskWithRequest(urlRequest) { (data, response, error) -> Void in
            defer {
                self.finish()
            }
            
            if self.cancelled {
                return
            }
            
            if let e = error {
                self.completion?(nil, e)
                
            } else {
                
                let response = response as! NSHTTPURLResponse
                switch response.statusCode {
                case 200:
                    if let JSON = try? NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) {
                        self.completion?(JSON as? [String : AnyObject], nil)
                    } else {
                        rvLog("Unexpected JSON", data: nil, level: .Error)
                        self.completion?(nil, NSError(domain: "io.rover.unexpectedjson", code: 13, userInfo: nil))
                    }
                case 204:
                    rvLog("No content", data: nil, level: .Trace)
                    self.completion?(nil, nil)
                case 404:
                    self.completion?(nil, NSError(domain: "io.rover.notfound", code: 10, userInfo: nil))
                case 400...499:
                    rvLog("Client error", data: nil, level: .Error)
                    self.completion?(nil, NSError(domain: "io.rover.clienterror", code: 11, userInfo: nil))
                case 500...599:
                    rvLog("Server error", data: response.statusCode, level: .Error)
                    self.completion?(nil, NSError(domain: "io.rover.servererror", code: 12, userInfo: nil))
                default:
                    rvLog("Invalid HTTP response", data: response.statusCode, level: .Error)
                    self.completion?(nil, NSError(domain: "io.rover.invalidresponse", code: 13, userInfo: nil))
                }
            }
        }
        
        urlSessionTask.resume()
    }
    
    
}

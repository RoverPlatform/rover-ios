//
//  NetworkOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation

class NetworkOperation: NSOperation {
    
    var urlRequest: NSMutableURLRequest
    var urlSessionTask: NSURLSessionDataTask?
    var payload: [String: AnyObject]?
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
    
    typealias JSONCompletionBlock = ([String: AnyObject]?, NSError?) -> Void
    
    required init(mutableUrlRequest: NSMutableURLRequest, completion: JSONCompletionBlock?) {
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
    
    override func start() {
        guard !cancelled else {
            finished = true
            return
        }
        
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
            
            // TODO:
            urlRequest.setValue("0628d761f3cebf6a586aa02cc4648bd2", forHTTPHeaderField: "X-Rover-Api-Key")
        } catch {
            // RVLOGERROR "Error with payload"
            cancel()
        }
        
        let urlSessionTask = NSURLSession.sharedSession().dataTaskWithRequest(urlRequest) { (data, response, error) -> Void in
            if let e = error {
                self.cancel()
                //self.completion(nil, e)
            } else {
                defer {
                    self.executing = false
                    self.finished = true
                }
                
                let response = response as! NSHTTPURLResponse
                switch response.statusCode {
                case 200:
                    if let JSON = try? NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) {
                        self.completion?(JSON as? [String : AnyObject], nil)
                    } else {
                        self.completion?(nil, NSError(domain: "io.rover.unexpectedjson", code: 13, userInfo: nil))
                    }
                    
                case 404: self.completion?(nil, NSError(domain: "io.rover.notfound", code: 10, userInfo: nil))
                case 400...499: self.completion?(nil, NSError(domain: "io.rover.clienterror", code: 11, userInfo: nil))
                case 500...599: self.completion?(nil, NSError(domain: "io.rover.servererror", code: 12, userInfo: nil))
                default:
                    print("Received HTTP \(response.statusCode), which was not handled")
                }
            }
        }
        
        executing = true
        urlSessionTask.resume()
    }
    
    override private(set) var finished: Bool {
        get {
            return _finished
        }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    
    override private(set) var executing: Bool {
        get {
            return _executing
        }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    
    override var concurrent: Bool {
        return true
    }
    
    
}

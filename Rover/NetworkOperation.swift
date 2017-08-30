//
//  NetworkOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation

open class NetworkOperation: ConcurrentOperation {
    
    var urlRequest: URLRequest
    var urlSessionTask: URLSessionDataTask?
    open var payload: [String: Any]?
    var completion: JSONCompletionBlock?
    
    fileprivate var payloadAsQuery: String {
        guard let payload = payload else { return "" }
        var params = [String]()
        for (key, value) in payload {
            params.append("\(key)=\(value)")
        }
        return params.joined(separator: "&")
    }
    
    fileprivate var _finished = false
    fileprivate var _executing = false
    
    public typealias JSONCompletionBlock = ([String: Any]?, Error?) -> Void
    
    required public init(urlRequest: URLRequest, completion: JSONCompletionBlock?) {
        self.urlRequest = urlRequest
        self.completion = completion
        super.init()
    }
    
    convenience init(url: URL, method: String, completion: JSONCompletionBlock?) {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        
        self.init(urlRequest: urlRequest, completion: completion)
    }

    override func execute() {
        do {
            if let payload = payload {
                switch self.urlRequest.httpMethod {
                case "GET"?:
                    urlRequest.url = URL(string: "\(urlRequest.url?.absoluteString ?? "")?\(payloadAsQuery)")
                default:
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
                }
            }
            
            urlRequest.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        } catch {
            self.completion?(nil, error)
            rvLog("Error creating network request", data: error, level: .error)
            finish()
            return
        }
        
        // TODO: maybe use KVO on URLSession like they do in AdvancedNSOperations example project

        let urlSessionTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) -> Void in
            defer {
                self.finish()
            }
            
            if self.isCancelled {
                return
            }
            
            if let e = error {
                self.completion?(nil, e)
                
            } else {
                
                let response = response as! HTTPURLResponse
                switch response.statusCode {
                case 200:
                    if let JSON = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                        self.completion?(JSON as? [String : Any], nil)
                    } else {
                        rvLog("Unexpected JSON", data: nil, level: .error)
                        self.completion?(nil, NSError(domain: "io.rover.unexpectedjson", code: 13, userInfo: nil))
                    }
                    
                    if let date = response.allHeaderFields["Expires"] as? String,
                        let cache = URLCache.shared.cachedResponse(for: self.urlRequest),
                        let cachedResponse = cache.response as? HTTPURLResponse,
                        let cachedDate = cachedResponse.allHeaderFields["Expires"] as? String,
                        let data = data {
                        
                        if date != cachedDate {
                            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: self.urlRequest)
                        }
                    }
                case 204:
                    rvLog("No content", data: nil, level: .trace)
                    self.completion?(nil, nil)
                case 404:
                    self.completion?(nil, NSError(domain: "io.rover.notfound", code: 10, userInfo: nil))
                case 400...499:
                    rvLog("Client error", data: nil, level: .error)
                    self.completion?(nil, NSError(domain: "io.rover.clienterror", code: 11, userInfo: nil))
                case 500...599:
                    rvLog("Server error", data: response.statusCode, level: .error)
                    self.completion?(nil, NSError(domain: "io.rover.servererror", code: 12, userInfo: nil))
                default:
                    rvLog("Invalid HTTP response", data: response.statusCode, level: .error)
                    self.completion?(nil, NSError(domain: "io.rover.invalidresponse", code: 13, userInfo: nil))
                }
            }
        }
        
        urlSessionTask.resume()
        
    }
    
    
}

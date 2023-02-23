// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import RoverFoundation

public protocol SyncClient {
    func task(with syncRequests: [SyncRequest], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask
}

extension SyncClient {
    public func queryItems(syncRequests: [SyncRequest]) -> [URLQueryItem] {
        let query: String = {
            let expression: String = {
                let signatures = syncRequests.compactMap { $0.query.signature }
                
                if signatures.isEmpty {
                    return ""
                }
                
                let joined = signatures.joined(separator: ", ")
                return "(\(joined))"
            }()
            
            let body: String = {
                syncRequests.map { $0.query.definition }.joined(separator: "\n")
            }()
            
            return """
                query Sync\(expression) {
                    \(body)
                }
                """
        }()
        
        let fragmentsUnsorted: [String]? = {
            let fragments = syncRequests.map { Set($0.query.fragments) }.reduce(Set<String>()) { $0.union($1) }
            return Array(fragments)
        }()
        
        let fragments = fragmentsUnsorted?.sorted()
        
        let variablesDict: [String: Any] = {
            syncRequests.reduce([String: Any]()) { result, request in
                request.variables.rawValue.reduce(result) { result, element in
                    var nextResult = result
                    nextResult["\(request.query.name)\(element.key.capitalized)"] = element.value
                    return nextResult
                }
            }
        }()
        
        let variables = Attributes(rawValue: variablesDict)
        
        let condensed = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: condensed)
        ]
        
        let encoder = JSONEncoder.default
        if let encoded = try? encoder.encode(variables) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "variables", value: value)
            queryItems.append(queryItem)
        }
        
        if let fragments = fragments, let encoded = try? encoder.encode(fragments) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "fragments", value: value)
            queryItems.append(queryItem)
        }
        
        return queryItems
    }
}

extension HTTPClient: SyncClient {
    public func task(with syncRequests: [SyncRequest], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask {
        let queryItems = self.queryItems(syncRequests: syncRequests)
        let urlRequest = self.downloadRequest(queryItems: queryItems)
        return self.downloadTask(with: urlRequest, completionHandler: completionHandler)
    }
}

//
//  StateFetcherService.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class StateFetcherService: StateFetcher {
    let client: GraphQLClient
    let logger: Logger
    
    init(client: GraphQLClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    // MARK: Foreground Monitoring
    
    var didFinishLaunchingObserver: NSObjectProtocol?
    var willEnterForegroundObserver: NSObjectProtocol?
    
    var isAutoFetchEnabled: Bool = false {
        didSet {
            [didFinishLaunchingObserver, willEnterForegroundObserver].compactMap({ $0 }).forEach(NotificationCenter.default.removeObserver)
            
            if isAutoFetchEnabled {
                didFinishLaunchingObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidFinishLaunching, object: nil, queue: nil) { [weak self] _ in
                    self?.fetchState { _ in }
                }
                
                willEnterForegroundObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil) { [weak self] _ in
                    self?.fetchState { _ in }
                }
            }
        }
    }
    
    // MARK: Fetching State
    
    func addQueryFragment(_ query: String, fragments: [String]?) {
        fetchQuery.queries.append(query)
        
        if let fragments = fragments {
            fetchQuery._fragments.append(contentsOf: fragments)
        }
    }
    
    struct FetchQuery: GraphQLOperation {
        var queries = [String]()
        
        var query: String {
            return """
                query {
                    device(identifier:\"\(UIDevice.current.identifierForVendor?.uuidString ?? "")\") {
                        \(queries.joined(separator: "\n"))
                    }
                }
                """
        }
        
        var _fragments = [String]()
        
        var fragments: [String]? {
            return _fragments
        }
    }
    
    var fetchQuery = FetchQuery()
    
    func fetchState(fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let task = client.task(with: fetchQuery) {
            let result: UIBackgroundFetchResult
            
            defer {
                completionHandler(result)
            }
            
            switch $0 {
            case .error(let error, _):
                self.logger.error("Failed to fetch state")
                if let error = error {
                    self.logger.error(error.localizedDescription)
                }
                
                result = .failed
            case .success(let data):
                self.observers.notify(parameters: data)
                result = .newData
            }
        }
        
        task.resume()
    }
    
    // MARK: Observers
    
    var observers = ObserverSet<Data>()
    
    func addObserver(block: @escaping (Data) -> Void) -> NSObjectProtocol {
        return observers.add(block: block)
    }
    
    func removeObserver(_ token: NSObjectProtocol) {
        observers.remove(token: token)
    }
}


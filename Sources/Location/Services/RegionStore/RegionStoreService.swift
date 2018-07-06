//
//  RegionStore.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-03-07.
//  Copyright © 2018 Sean Rucker. All rights reserved.
//

import UIKit

class RegionStoreService: RegionStore {
    let client: GraphQLClient
    let logger: Logger
    
    var regions = Set<Region>() {
        didSet {
            observers.notify(parameters: regions)
        }
    }

    var observers = ObserverSet<Set<Region>>()
    var stateObservation: NSObjectProtocol?
    
    init(client: GraphQLClient, logger: Logger, stateFetcher: StateFetcher) {
        self.client = client
        self.logger = logger
        
        stateFetcher.addQueryFragment(RegionStoreService.queryFragment, fragments: RegionStoreService.fragments)
        
        stateObservation = stateFetcher.addObserver { data in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
            if let response = try? decoder.decode(FetchResponse.self, from: data) {
                self.regions = response.data.device.regions
            }
        }
    }
    
    // MARK: Observers
    
    func addObserver(block: @escaping (Set<Region>) -> Void) -> NSObjectProtocol {
        return observers.add(block: block)
    }
    
    func removeObserver(_ token: NSObjectProtocol) {
        observers.remove(token: token)
    }
    
    // MARK: Fetching Regions
    
    static let queryFragment = """
        regions {
            ...regionFields
        }
        """
    
    static let fragments = ["regionFields"]
    
    struct FetchQuery: GraphQLOperation {
        var query: String {
            return """
                query {
                    device(identifier:\"\(UIDevice.current.identifierForVendor?.uuidString ?? "")\") {
                        \(RegionStoreService.queryFragment)
                    }
                }
                """
        }
        
        var fragments: [String]? {
            return RegionStoreService.fragments
        }
    }
    
    struct FetchResponse: Decodable {
        struct Data: Decodable {
            struct Device: Decodable {
                var regions: Set<Region>
            }
            
            var device: Device
        }
        
        var data: Data
    }
    
    func fetchRegions(completionHandler: ((FetchRegionsResult) -> Void)?) {
        let operation = FetchQuery()
        let task = client.task(with: operation) {
            let result: FetchRegionsResult
            
            defer {
                completionHandler?(result)
            }
            
            switch $0 {
            case .error(let error, let isRetryable):
                self.logger.error("Failed to fetch regions")
                if let error = error {
                    self.logger.error(error.localizedDescription)
                }
                
                result = FetchRegionsResult.error(error: error, isRetryable: isRetryable)
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
                    let response = try decoder.decode(FetchResponse.self, from: data)
                    let regions = response.data.device.regions
                    self.regions = regions
                    result = FetchRegionsResult.success(regions: regions)
                } catch {
                    self.logger.error("Failed to decode regions from GraphQL response")
                    self.logger.error(error.localizedDescription)
                    result = FetchRegionsResult.error(error: error, isRetryable: false)
                }
            }
        }
        
        task.resume()
    }
}

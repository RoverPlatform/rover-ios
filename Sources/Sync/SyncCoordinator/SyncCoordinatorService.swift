//
//  SyncCoordinatorService.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class SyncCoordinatorService: SyncCoordinator {
    let client: SyncClient

    var syncTask: URLSessionTask?
    var completionHandlers = [(UIBackgroundFetchResult) -> Void]()
    
    var participants = [SyncParticipant]()
    
    init(client: SyncClient) {
        self.client = client
    }
    
    func sync(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        var intialParticipants = [SyncParticipant]()
        var initialVariables = [String: Any]()
        
        for participant in self.participants {
            if let requestVariables = participant.initialRequestVariables() {
                intialParticipants.append(participant)
                initialVariables.merge(requestVariables) { _, targetVal -> Any in
                    // no collisions are expected however .merge requires an explicit collision strategy.
                    targetVal
                }
            }
        }
        
        let participantNames = self.participants.map { String(describing: type(of: $0)) }.joined(separator: ", ")
    
        os_log("Beginning sync with [%s].", log: .persistence, type: .info, participantNames)
        
        self.sync(participants: intialParticipants, variables: initialVariables, completionHandler: completionHandler)
    }
    
    func sync(participants: [SyncParticipant], variables: [String: Any], completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        if let newHandler = completionHandler {
            self.completionHandlers.append(newHandler)
        }
        
        if self.syncTask != nil {
            os_log("Sync already in-progress", log: .sync, type: .debug)
            return
        }
        
        self.recursiveSync(participants: participants, variables: variables)
    }
    
    func recursiveSync(participants: [SyncParticipant], variables: [String: Any], newData: Bool = false) {
        if participants.isEmpty {
            if newData {
                self.invokeCompletionHandlers(.newData)
            } else {
                self.invokeCompletionHandlers(.noData)
            }
            
            return
        }
        
        // Refactoring this wouldn't add a lot of value, so silence the closure length warning.
        // swiftlint:disable:next closure_body_length
        let task = self.client.task(with: variables) { [weak self] result in
            guard let _self = self else {
                return
            }
            
            _self.syncTask = nil
            
            switch result {
            case .error(let error, _):
                if let error = error {
                    os_log("Sync task failed: %@", log: .sync, type: .error, error.localizedDescription)
                } else {
                    os_log("Sync task failed", log: .sync, type: .error)
                }
                
                _self.invokeCompletionHandlers(.failed)
            case .success(let data):
                var results = [SyncResult]()
                var nextParticipants = [SyncParticipant]()
                var aggregateNextRequestVariables = [String: Any]()
                var newData = newData
                
                for participant in participants {
                    let result = participant.saveResponse(data)
                    results.append(result)
                    
                    if case .newData(let nextRequestVariables) = result {
                        newData = true
                        if let nextRequestVariables = nextRequestVariables {
                            nextParticipants.append(participant)
                            aggregateNextRequestVariables.merge(nextRequestVariables, uniquingKeysWith: { _, targetVal in
                                // collision not expected.
                                targetVal
                            })
                        }
                    }
                }
                
                _self.recursiveSync(participants: nextParticipants, variables: aggregateNextRequestVariables, newData: newData)
            }
        }
        
        task.resume()
        self.syncTask = task
    }
    
    func invokeCompletionHandlers(_ result: UIBackgroundFetchResult) {
        let completionHandlers = self.completionHandlers
        self.completionHandlers = []
        completionHandlers.forEach { $0(result) }
    }
}

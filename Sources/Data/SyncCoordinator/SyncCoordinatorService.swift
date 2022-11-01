//
//  SyncCoordinatorService.swift
//  RoverData
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
        var intialRequests = [SyncRequest]()
        
        for participant in self.participants {
            if let request = participant.initialRequest() {
                intialParticipants.append(participant)
                intialRequests.append(request)
            }
        }
        
        self.sync(participants: intialParticipants, requests: intialRequests, completionHandler: completionHandler)
    }
    
    func sync(participants: [SyncParticipant], requests: [SyncRequest], completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        if let newHandler = completionHandler {
            self.completionHandlers.append(newHandler)
        }
        
        if self.syncTask != nil {
            os_log("Sync already in-progress", log: .sync, type: .debug)
            return
        }
        
        self.recursiveSync(participants: participants, requests: requests)
    }
    
    func recursiveSync(participants: [SyncParticipant], requests: [SyncRequest], newData: Bool = false) {
        if participants.isEmpty || requests.isEmpty {
            if newData {
                self.invokeCompletionHandlers(.newData)
            } else {
                self.invokeCompletionHandlers(.noData)
            }
            
            return
        }
        
        // Refactoring this wouldn't add a lot of value, so silence the closure length warning.
        // swiftlint:disable:next closure_body_length
        let task = self.client.task(with: requests) { [weak self] result in
            DispatchQueue.main.async {
                guard let _self = self else {
                    return
                }
                
                _self.syncTask = nil
                
                switch result {
                case .error(let error, _):
                    if let error = error {
                        os_log("Sync task failed: %@", log: .sync, type: .error, error.logDescription)
                    } else {
                        os_log("Sync task failed", log: .sync, type: .error)
                    }
                    
                    _self.invokeCompletionHandlers(.failed)
                case .success(let data):
                    var results = [SyncResult]()
                    var nextParticipants = [SyncParticipant]()
                    var nextRequests = [SyncRequest]()
                    var newData = newData
                    
                    for participant in participants {
                        let result = participant.saveResponse(data)
                        results.append(result)
                        
                        if case .newData(let nextRequest) = result {
                            newData = true
                            if let nextRequest = nextRequest {
                                nextParticipants.append(participant)
                                nextRequests.append(nextRequest)
                            }
                        }
                    }
                    
                    _self.recursiveSync(participants: nextParticipants, requests: nextRequests, newData: newData)
                }
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

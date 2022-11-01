//
//  UserDefaults+PollsStorage.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import Foundation


private let USER_DEFAULTS_STORAGE_KEY = "io.rover.Polls.storage"

extension UserDefaults {
    
    struct PollStorageRecord<T>: Codable where T: Codable {
        var pollID: String
        var poll: T
    }
    
    func writeStateJSONForPoll<T: Codable>(id: String, json: T) {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
            
        let existingRecords: [PollStorageRecord<T>]
        if let existingPollsJson = self.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                existingRecords = try decoder.decode([PollStorageRecord<T>].self, from: existingPollsJson)
            } catch {
                os_log("Existing storage for polls was corrupted, resetting: %s", log: .rover, type: .error, error.debugDescription)
                existingRecords = []
            }
        } else {
            existingRecords = []
        }
        
        let record = PollStorageRecord<T>(pollID: id, poll: json)
        
        // delete existing entry if one is present and prepend the new one:
        let records = [record] + existingRecords.filter { $0.pollID != id }
        
        // drop any stored states past 100:
        let trimmedNewRecords: [PollStorageRecord<T>] = Array(records.prefix(100))
        
        let droppedRecords = records.count - trimmedNewRecords.count
        
        if droppedRecords > 0 {
            os_log("Dropped %d poll storage records.", log: .rover, type: .debug, droppedRecords)
        }
        
        do {
            let newStateJson = try encoder.encode(trimmedNewRecords)
            self.set(newStateJson, forKey: USER_DEFAULTS_STORAGE_KEY)
        } catch {
            os_log("Unable to update local poll storage: %s", log: .rover, type: .error, error.debugDescription)
            return
        }
        os_log("Updated local state for poll %s.", log: .rover, type: .debug, id)
        
    }
    
    func retrieveStateJSONForPoll<T: Codable>(id: String) -> T? {
        let decoder = JSONDecoder()
        if let existingPollsJson = self.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                let pollStates = try decoder.decode([PollStorageRecord<T>].self, from: existingPollsJson)
                
                return pollStates.first(where: { $0.pollID == id })?.poll
            } catch {
                os_log("Existing storage for polls was corrupted: %s", error.debugDescription)
                return nil
            }
        } else {
            return nil
        }
    }
}

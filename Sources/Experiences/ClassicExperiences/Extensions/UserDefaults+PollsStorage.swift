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

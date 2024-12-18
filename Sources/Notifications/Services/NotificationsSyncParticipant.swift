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

import os.log
import RoverFoundation
import RoverData
import UIKit

class NotificationsSyncParticipant: SyncParticipant {
    let store: NotificationStore
    
    init(store: NotificationStore) {
        self.store = store
    }
    
    func initialRequest() -> SyncRequest? {
        guard let uuidString = UIDevice.current.identifierForVendor?.uuidString else {
            return nil
        }
        
        let orderBy: Attributes = [
            "field": "CREATED_AT",
            "direction": "DESC"
        ]
        
        return SyncRequest(
            query: SyncQuery.notifications,
            values: [
                "last": 500,
                "orderBy": orderBy,
                "deviceIdentifier": uuidString
            ]
        )
    }
    
    func saveResponse(_ data: Data) -> SyncResult {
        let response: Response
        do {
            response = try JSONDecoder.default.decode(Response.self, from: data)
        } catch {
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.logDescription)
            return .failed
        }
        
        guard let nodes = response.data.notifications.nodes, nodes != self.store.notifications else {
            return .noData
        }
        
        self.store.addNotifications(nodes)
        return .newData(nextRequest: nil)
    }
}

private struct Response: Decodable {
    struct Data: Decodable {
        struct Notifications: Decodable {
            var nodes: [Notification]?
        }
        
        var notifications: Notifications
    }
    
    var data: Data
}

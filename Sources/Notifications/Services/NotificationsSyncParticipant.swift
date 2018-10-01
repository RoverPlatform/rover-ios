//
//  NotificationsSyncParticipant.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class NotificationsSyncParticipant: SyncParticipant {
    let store: NotificationStore
    
    init(store: NotificationStore) {
        self.store = store
    }
    
    func initialRequest() -> SyncRequest? {
        let deviceIdentifier = UIDevice.current.identifierForVendor!.uuidString
        return SyncRequest(
            query: SyncQuery.notifications,
            values: [
                SyncQuery.Argument.last: 500,
                SyncQuery.Argument.deviceIdentifier: deviceIdentifier
            ]
        )!
    }
    
    func saveResponse(_ data: Data) -> SyncResult {
        let response: Response
        do {
            response = try JSONDecoder.default.decode(Response.self, from: data)
        } catch {
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.localizedDescription)
            return .failed
        }
        
        guard let nodes = response.data.notifications.nodes, nodes != self.store.notifications else {
            return .noData
        }
        
        self.store.addNotifications(nodes)
        return .newData(nextRequest: nil)
    }
}

fileprivate struct Response: Decodable {
    struct Data: Decodable {
        struct Notifications: Decodable {
            var nodes: [Notification]?
        }
        
        var notifications: Notifications
    }
    
    var data: Data
}

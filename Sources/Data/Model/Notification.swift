//
//  Notification.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData

public final class Notification: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Notification> {
        return NSFetchRequest<Notification>(entityName: "Notification")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var campaignID: String
    @NSManaged public internal(set) var title: String?
    @NSManaged public internal(set) var body: String
    @NSManaged public internal(set) var attachment: NotificationAttachment?
    @NSManaged public internal(set) var tapBehavior: NotificationTapBehavior
    @NSManaged public internal(set) var deliveredAt: Date
    @NSManaged public internal(set) var expiresAt: Date?
    @NSManaged public internal(set) var isRead: Bool
        
    // MARK: Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case campaignID
        case title
        case body
        case attachment
        case tapBehavior
        case deliveredAt
        case expiresAt
        case isRead
    }
}

extension Notification {
    public func openedEvent(source: NotificationSource) -> EventInfo {
        let attributes: Attributes = [
            "notification": self,
            "source": source.rawValue
        ]
        return EventInfo(name: "Notification Opened", namespace: "rover", attributes: attributes)
    }
}

extension Notification {
    public var attributes: Attributes {
        return [
            "id": id,
            "campaignID": campaignID
        ]
    }
}

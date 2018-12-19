//
//  Notification.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData

public final class Notification: NSManagedObject, Codable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Notification> {
        return NSFetchRequest<Notification>(entityName: "Notification")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var campaignID: String
    @NSManaged public internal(set) var title: String?
    @NSManaged public internal(set) var body: String
    @NSManaged public internal(set) var attachment: NotificationAttachment?
    // TODO: ANDREW START HERE and explore how to get a Swift enum -- and a *complex* enum with different params on each case -- most elegantly persisted into Core Data.
    @NSManaged public internal(set) var tapBehavior: NotificationTapBehavior
    @NSManaged public internal(set) var deliveredAt: Date
    @NSManaged public internal(set) var expiresAt: Date?
    @NSManaged public internal(set) var isRead: Bool
    @NSManaged public internal(set) var isNotificationCenterEnabled: Bool
    @NSManaged public internal(set) var is_Deleted: Bool
    
//    public var hashValue: Int {
//        return id.hashValue
//    }
    
    // MARK: Codable
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.campaignID = try values.decode(String.self, forKey: .campaignID)
        self.title = try? values.decode(String.self, forKey: .title)
        self.body = try values.decode(String.self, forKey: .body)
        self.attachment = try? values.decode(NotificationAttachment.self, forKey: .attachment)
        self.tapBehavior = try values.decode(NotificationTapBehavior.self, forKey: .tapBehavior)
        self.deliveredAt = try values.decode(Date.self, forKey: .deliveredAt)
        self.expiresAt = try? values.decode(Date.self, forKey: .expiresAt)
        self.isRead = try values.decode(Bool.self, forKey: .isRead)
        self.isNotificationCenterEnabled = try values.decode(Bool.self, forKey: .isNotificationCenterEnabled)
        self.is_Deleted = try values.decode(Bool.self, forKey: .isDeleted)
    }
    
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
        case isNotificationCenterEnabled
        case isDeleted
    }
    
    
//    public init(id: String, campaignID: String, title: String?, body: String, attachment: NotificationAttachment?, tapBehavior: NotificationTapBehavior, deliveredAt: Date, expiresAt: Date?, isRead: Bool, isNotificationCenterEnabled: Bool, isDeleted: Bool) {
//        self.id = id
//        self.campaignID = campaignID
//        self.title = title
//        self.body = body
//        self.attachment = attachment
//        self.tapBehavior = tapBehavior
//        self.deliveredAt = deliveredAt
//        self.expiresAt = expiresAt
//        self.isRead = isRead
//        self.isNotificationCenterEnabled = isNotificationCenterEnabled
//        self.is_Deleted = isDeleted
//    }
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

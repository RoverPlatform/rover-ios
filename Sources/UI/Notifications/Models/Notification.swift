//
//  Notification.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct Notification: Codable, Equatable, Hashable {
    public var id: String
    public var campaignID: String
    public var title: String?
    public var body: String
    public var attachment: NotificationAttachment?
    public var tapBehavior: NotificationTapBehavior
    public var deliveredAt: Date
    public var expiresAt: Date?
    public var isRead: Bool
    public var isNotificationCenterEnabled: Bool
    public var isDeleted: Bool
    
    public var hashValue: Int {
        return id.hashValue
    }
    
    public init(id: String, campaignID: String, title: String?, body: String, attachment: NotificationAttachment?, tapBehavior: NotificationTapBehavior, deliveredAt: Date, expiresAt: Date?, isRead: Bool, isNotificationCenterEnabled: Bool, isDeleted: Bool) {
        self.id = id
        self.campaignID = campaignID
        self.title = title
        self.body = body
        self.attachment = attachment
        self.tapBehavior = tapBehavior
        self.deliveredAt = deliveredAt
        self.expiresAt = expiresAt
        self.isRead = isRead
        self.isNotificationCenterEnabled = isNotificationCenterEnabled
        self.isDeleted = isDeleted
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

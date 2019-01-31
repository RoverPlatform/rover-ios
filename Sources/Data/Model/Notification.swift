//
//  Notification.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

public final class Notification: NSManagedObject {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Notification> {
        return NSFetchRequest<Notification>(entityName: "Notification")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var campaignID: String
    @NSManaged public var title: String?
    @NSManaged public var body: String
    @NSManaged public var deliveredAt: Date
    @NSManaged public var isRead: Bool
    
    override public func awakeFromInsert() {
        self.id = UUID()
        super.awakeFromInsert()
    }
}

extension Notification {
    public func openedEvent(source: NotificationSource) -> EventInfo {
        let attributes: Attributes = [
            "notification": self.attributes,
            "source": source.rawValue
        ]
        return EventInfo(name: "Notification Opened", namespace: "rover", attributes: attributes)
    }
}

extension Notification {
    public var attributes: Attributes {
        return [
            "id": self.id.uuidString,
            "campaignID": campaignID
        ]
    }
}

extension Notification {
    public func markRead() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot mark read.")
            return
        }
        
        self.isRead = true

        managedObjectContext.perform {
            managedObjectContext.saveOrRollback()
        }
    }
    
    public func delete() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot delete.")
            return
        }
        
        managedObjectContext.perform {
            managedObjectContext.delete(self)
            managedObjectContext.saveOrRollback()
        }
    }
    
    public func attemptInsert() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot insert.")
            return
        }
        
        managedObjectContext.perform {
            managedObjectContext.insert(self)
            managedObjectContext.saveOrRollback()
        }
    }
}

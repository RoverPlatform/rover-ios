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
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Notification> {
        return NSFetchRequest<Notification>(entityName: "Notification")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var campaignID: String
    @NSManaged public var title: String?
    @NSManaged public var body: String
//    @NSManaged public internal(set) var attachment: NotificationAttachment?
//    @NSManaged public internal(set) var tapBehavior: NotificationTapBehavior
    @NSManaged public var deliveredAt: Date
//    @NSManaged public internal(set) var expiresAt: Date?
    @NSManaged public var isRead: Bool
    
    public override func awakeFromInsert() {
        self.id = UUID()
        super.awakeFromInsert()
    }
    
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
            "id": self.objectID,
            "campaignID": campaignID
        ]
    }
}

extension Notification {
    public func markRead() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot delete.")
            return
        }
        
        self.isRead = true
        
        managedObjectContext.perform {
            do {
                try managedObjectContext.save()
            } catch {
                if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                    multipleErrors.forEach {
                        os_log("Unable to delete Notification. Reason: %s", log: .persistence, type: .error, $0.localizedDescription)
                    }
                } else {
                    os_log("Unable to delete Notification. Reason: %s", log: .persistence, type: .error, error.localizedDescription)
                }
                
                managedObjectContext.rollback()
            }
        }
    }
    
    public func delete() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot delete.")
            return
        }
        
        managedObjectContext.perform {
            managedObjectContext.delete(self)
            
            do {
                try managedObjectContext.save()
            } catch {
                if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                    multipleErrors.forEach {
                        os_log("Unable to delete Notification. Reason: %s", log: .persistence, type: .error, $0.localizedDescription)
                    }
                } else {
                    os_log("Unable to delete Notification. Reason: %s", log: .persistence, type: .error, error.localizedDescription)
                }
                
                managedObjectContext.rollback()
            }
        }
    }
    
    public func attemptInsert() {
        guard let managedObjectContext = self.managedObjectContext else {
            assertionFailure("Not associated with a managed object context, cannot delete.")
            return
        }
        
        managedObjectContext.perform {
            managedObjectContext.insert(self)
            
            do {
                try managedObjectContext.save()
            } catch {
                if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                    multipleErrors.forEach {
                        os_log("Unable to save notification into local storage. Dropping it. Reason: %s", log: .persistence, type: .error,  ($0 as NSError).userInfo.debugDescription)
                    }
                } else {
                    os_log("Unable to save the notification into local storage. Dropping it. Reason: %s", log: .persistence, type: .error, (error as NSError).userInfo.debugDescription)
                }
                
                managedObjectContext.rollback()
            }
        }
    }
}

//
//  CampaignNotificationDeliverable.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-02-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

final public class CampaignNotificationDeliverable: CampaignDeliverable {
    public struct InsertionInfo {
        var body: String
        var title: String?
        var showInNotificationCenter: Bool
        var showBadgeNumber: Bool
        var showSystemNotification: Bool
        var iosCategoryIdentifier: String?
        var iosMutableContent: Bool
        var iosSound: String?
        var iosThreadIdentifier: String?
        var tapBehaviorType: TapBehaviorType
        var tapBehaviorUrl: String
        var attachmentType: AttachmentType?
        var attachmentUrl: String?

        public init(
            body: String,
            title: String?,
            showInNotificationCenter: Bool,
            showBadgeNumber: Bool,
            showSystemNotification: Bool,
            iosCategoryIdentifier: String?,
            iosMutableContent: Bool,
            iosSound: String?,
            iosThreadIdentifier: String?,
            tapBehaviorType: TapBehaviorType,
            tapBehaviorUrl: String,
            attachmentUrl: String?,
            attachmentType: AttachmentType?
        ) {
            self.body = body
            self.title = title
            self.showInNotificationCenter = showInNotificationCenter
            self.showBadgeNumber = showBadgeNumber
            self.showSystemNotification = showSystemNotification
            self.iosCategoryIdentifier = iosCategoryIdentifier
            self.iosMutableContent = iosMutableContent
            self.iosSound = iosSound
            self.iosThreadIdentifier = iosThreadIdentifier
            self.tapBehaviorType = tapBehaviorType
            self.tapBehaviorUrl = tapBehaviorUrl
            self.attachmentUrl = attachmentUrl
            self.attachmentType = attachmentType
        }
    }
    
    @discardableResult
    public static func insert(
        into context: NSManagedObjectContext,
        insertionInfo: InsertionInfo
    ) -> CampaignNotificationDeliverable {
        let deliverable = CampaignNotificationDeliverable(context: context)
        deliverable.body = insertionInfo.body
        deliverable.title = insertionInfo.title
        deliverable.showInNotificationCenter = insertionInfo.showInNotificationCenter
        deliverable.showBadgeNumber = insertionInfo.showBadgeNumber
        deliverable.showSystemNotification = insertionInfo.showSystemNotification
        deliverable.iosCategoryIdentifier = insertionInfo.iosCategoryIdentifier
        deliverable.iosMutableContent = insertionInfo.iosMutableContent
        deliverable.iosSound = insertionInfo.iosSound
        deliverable.iosThreadIdentifier = insertionInfo.iosThreadIdentifier
        deliverable.attachmentUrl = insertionInfo.attachmentUrl
        return deliverable
    }
    
    @NSManaged public private(set) var campaign: Campaign
    
    @NSManaged public private(set) var body: String
    
    @NSManaged public private(set) var title: String?
    
    @NSManaged public private(set) var showInNotificationCenter: Bool
    
    @NSManaged public private(set) var showBadgeNumber: Bool
    
    @NSManaged public private(set) var showSystemNotification: Bool
    
    @NSManaged public private(set) var iosCategoryIdentifier: String?
    
    @NSManaged public private(set) var iosMutableContent: Bool
    
    @NSManaged public private(set) var iosSound: String?
    
    @NSManaged public private(set) var iosThreadIdentifier: String?
    
    @NSManaged public private(set) var attachmentUrl: String?
    
    public internal(set) var attachmentType: AttachmentType? {
        get {
            self.willAccessValue(forKey: ComputedAttributes.attachmentType.rawValue)
            defer { self.didAccessValue(forKey: ComputedAttributes.attachmentType.rawValue) }
            guard let primitiveValue = primitiveValue(forKey: ComputedAttributes.attachmentType.rawValue) as? String else {
                return nil
            }
            
            return AttachmentType(rawValue: primitiveValue)
        }
        set {
            willChangeValue(forKey: ComputedAttributes.attachmentType.rawValue)
            defer { didChangeValue(forKey: ComputedAttributes.attachmentType.rawValue) }
            
            setPrimitiveValue(newValue?.rawValue, forKey: ComputedAttributes.attachmentType.rawValue)
        }
    }
    
    @NSManaged public private(set) var tapBehaviorUrl: String
    
    public internal(set) var tapBehaviorType: TapBehaviorType {
        get {
            self.willAccessValue(forKey: ComputedAttributes.tapBehaviorType.rawValue)
            defer { self.didAccessValue(forKey: ComputedAttributes.tapBehaviorType.rawValue) }
            guard let primitiveValue = primitiveValue(forKey: ComputedAttributes.tapBehaviorType.rawValue) as? String else {
                os_log("Invalid tap behavior type found in local storage, defaulting to OpenURL.", log: .persistence, type: .error)
                return .openURL // default to this.
            }
            
            return TapBehaviorType(rawValue: primitiveValue) ?? .openURL
        }
        set {
            willChangeValue(forKey: ComputedAttributes.tapBehaviorType.rawValue)
            defer { didChangeValue(forKey: ComputedAttributes.tapBehaviorType.rawValue) }
            
            setPrimitiveValue(newValue.rawValue, forKey: ComputedAttributes.tapBehaviorType.rawValue)
        }
    }
    
    public enum TapBehaviorType: String {
        case `default`
        case openURL
        case presentExperience
        case presentWebsite
    }
    
    public enum AttachmentType: String {
        case audio
        case image
        case video
    }
    
    private enum ComputedAttributes: String {
        case tapBehaviorType
        case attachmentType
    }
}

//
//  CampaignSyncParticipant.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os.log

class CampaignSyncParticipant: PagingSyncParticipant {
    typealias Storage = CoreDataSyncStorage
    typealias Response = CampaignsSyncResponse
    
    let userDefaults: UserDefaults
    let syncStorage: Storage<CampaignNode>
    
    var cursorKey: String {
        return "io.rover.RoverSync.campaignsCursor"
    }
    
    init(syncStorage: Storage<CampaignNode>, userDefaults: UserDefaults) {
        self.syncStorage = syncStorage
        self.userDefaults = userDefaults
    }
    
    func nextRequestVariables(cursor: String?) -> [String: Any] {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "campaignsFirst": 10, // TODO: sane page size?
            "campaignsOrderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["campaignsAfter"] = cursor
        }
        
        return values
    }
}

struct CampaignsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Campaigns: Decodable {
            var nodes: [CampaignNode]
            var pageInfo: PageInfo
        }
        
        var campaigns: Campaigns
    }
    
    var data: Data
}

extension CampaignsSyncResponse: PagingResponse {
    var nodes: [CampaignNode]? {
        return data.campaigns.nodes
    }
    
    var pageInfo: PageInfo {
        return data.campaigns.pageInfo
    }
}

extension CampaignNode: CoreDataStorable {
    func store(context: NSManagedObjectContext) {
        // flatten out the Campaign structures into a more storable and queryable form, in the shape of our AutomatedCampaign and ScheduledCampaign Core Data models.
        switch self.trigger {
        case let trigger as ScheduledCampaignTrigger:
            let campaign = ScheduledCampaign.insert(into: context)
        case let trigger as AutomatedCampaignTrigger:
            let dayOfWeekFilter = trigger.eventTrigger.filters.firstOfType(where: DayOfTheWeekEventTriggerFilter.self)
            let eventAttributesFilter = trigger.eventTrigger.filters.firstOfType(where: EventAttributesEventTriggerFilter.self)
            let scheduledFilter = trigger.eventTrigger.filters.firstOfType(where: ScheduledEventTriggerFilter.self)
            let timeOfDayFilter = trigger.eventTrigger.filters.firstOfType(where: TimeOfDayEventTriggerFilter.self)
            
            // and now build the deliverable.
            guard let storedDeliverable = RoverData.CampaignDeliverable.initFrom(syncCampaignDeliverable: self.deliverable, in: context) else {
                os_log("Unable to coerce campaign deliverable to form meant for local storage, unable to store this campaign.", log: .persistence, type: .error)
                return
            }
        
            let insertionInfo = AutomatedCampaign.InsertionInfo(
                id: self.id,
                eventTriggerEventName: trigger.eventTrigger.eventName,
                eventTriggerEventNamespace: trigger.eventTrigger.eventNamespace,
                deliverable: storedDeliverable,
                delay: trigger.delay,
                hasDayOfWeekFilter: dayOfWeekFilter != nil,
                hasTimeOfDayFilter: timeOfDayFilter != nil,
                hasEventAttributeFilter: eventAttributesFilter != nil,
                hasScheduledFilter: scheduledFilter != nil,
                dayOfWeekFilterMonday: dayOfWeekFilter?.monday ?? false,
                dayOfWeekFilterTuesday: dayOfWeekFilter?.tuesday ?? false,
                dayOfWeekFilterWednesday: dayOfWeekFilter?.wednesday ?? false,
                dayOfWeekFilterThursday: dayOfWeekFilter?.thursday ?? false,
                dayOfWeekFilterFriday: dayOfWeekFilter?.friday ?? false,
                dayOfWeekFilterSaturday: dayOfWeekFilter?.saturday ?? false,
                dayOfWeekFilterSunday: dayOfWeekFilter?.sunday ?? false,
                timeOfDayFilterStartTime: timeOfDayFilter?.startTime ?? 0,
                timeOfDayFilterEndTime: timeOfDayFilter?.endTime ?? 0,
                deviceFilterPredicate: trigger.segment?.predicate,
                eventAttributeFilterPredicate: eventAttributesFilter?.predicate,
                scheduledFilterStartDateTime: RoverData.DateTimeComponents(fromSyncDateTimeComponents: scheduledFilter?.startDateTime),
                scheduledFilterEndDateTime: RoverData.DateTimeComponents(fromSyncDateTimeComponents: scheduledFilter?.endDateTime)
            )
            
            _ = AutomatedCampaign.insert(into: context, insertionInfo: insertionInfo)
        default:
            fatalError("Some other type somehow appeared for CampaignTrigger")
        }
    }
}

extension Array {
    public func firstOfType<Element>(where type: Element.Type) -> Element? {
        return self.compactMap { element -> Element? in
            element as? Element
        }.first
    }
}

extension RoverData.DateTimeComponents {
    /// Construct a DateTimeComponents structure in the Data Module from the DateTimeComponents structure DTO.
    init(fromSyncDateTimeComponents source: DateTimeComponents) {
        self.init(
            date: source.date,
            time: source.time,
            timeZone: source.timeZone
        )
    }
    
    /// Construct a DateTimeComponents structure in the Data Module from the DateTimeComponents structure DTO, if one is present.
    init?(fromSyncDateTimeComponents source: DateTimeComponents?) {
        guard let source = source else {
            return nil
        }
        self.init(
            date: source.date,
            time: source.time,
            timeZone: source.timeZone
        )
    }
}

extension RoverData.CampaignDeliverable {
    static func initFrom(syncCampaignDeliverable source: CampaignDeliverable, in context: NSManagedObjectContext) -> RoverData.NotificationCampaignDeliverable? {
        switch source {
        case let notificationDeliverable as NotificationCampaignDeliverable:
            let attachmentType: RoverData.NotificationCampaignDeliverable.AttachmentType?
            
            if let attachmentTypeFromNode = notificationDeliverable.attachment?.type {
                switch attachmentTypeFromNode {
                case .audio:
                    attachmentType = .audio
                case .video:
                    attachmentType = .video
                case .image:
                    attachmentType = .image
                }
            } else {
                attachmentType = nil
            }
            
            let tapBehaviorType: RoverData.NotificationCampaignDeliverable.TapBehaviorType
            switch notificationDeliverable.tapBehavior.type {
            case .default_:
                tapBehaviorType = .default
            case .openURL:
                tapBehaviorType = .openURL
            case .presentExperience:
                tapBehaviorType = .presentExperience
            case .presentWebsite:
                tapBehaviorType = .presentWebsite
            }
            
            let deliverableInsertionInfo = RoverData.NotificationCampaignDeliverable.InsertionInfo(
                body: notificationDeliverable.body,
                title: notificationDeliverable.title,
                showInNotificationCenter: notificationDeliverable.alertOptions.notificationCenter,
                showBadgeNumber: notificationDeliverable.alertOptions.badgeNumber,
                showSystemNotification: notificationDeliverable.alertOptions.systemNotification,
                iosCategoryIdentifier: notificationDeliverable.iOSOptions?.categoryIdentifier,
                iosMutableContent: notificationDeliverable.iOSOptions?.mutableContent ?? false,
                iosSound: notificationDeliverable.iOSOptions?.sound,
                iosThreadIdentifier: notificationDeliverable.iOSOptions?.threadIdentifier,
                tapBehaviorType: tapBehaviorType,
                tapBehaviorUrl: notificationDeliverable.tapBehavior.url.absoluteString,
                attachmentUrl: notificationDeliverable.attachment?.url.absoluteString,
                attachmentType: attachmentType
            )
            return RoverData.NotificationCampaignDeliverable.insert(into: context, insertionInfo: deliverableInsertionInfo)
        default:
            os_log("Only NotificationCampaignDeliverables are currently supported for local persistent storage.", log: .persistence, type: .error)
            return nil
        }
    }
}

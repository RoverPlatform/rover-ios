//
//  NotificationHandlerService.swift
//  RoverCampaigns
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications
import UIKit
import os

class NotificationHandlerService: NotificationHandler {
    let influenceTracker: InfluenceTracker
    
    public typealias WebsiteViewControllerProvider = (URL) -> UIViewController?
    public let websiteViewControllerProvider: WebsiteViewControllerProvider
    
    let eventPipeline: EventPipeline
    
    init(influenceTracker: InfluenceTracker, eventPipeline: EventPipeline, websiteViewControllerProvider: @escaping WebsiteViewControllerProvider) {
        self.influenceTracker = influenceTracker
        self.eventPipeline = eventPipeline
        self.websiteViewControllerProvider = websiteViewControllerProvider
    }
    
    func handle(_ response: UNNotificationResponse) -> Bool {
        // The app was opened directly from a push notification. Clear the last received
        // notification from the influence tracker so we don't erroneously track an influenced open.
        influenceTracker.clearLastReceivedNotification()
        
        // TODO: all this is is changing with Campaigns.
        
//        guard let notification = response.roverNotification else {
//            return false
//        }
//
//
//        notificationStore.addNotification(notification)
//
//        if !notification.isRead {
//            notification.markRead()
//        }
//
//        switch notification.tapBehavior {
//        case is OpenAppTapBehavior:
//            break
//        case let tapBehavior as OpenURLTapBehavior:
//            let url = tapBehavior.url
//            UIApplication.shared.open(url, options: [:], completionHandler: nil)
//        case let tapBehavior as PresentWebsiteTapBehavior:
//            let url = tapBehavior.url
//            if let websiteViewController = websiteViewControllerProvider(url) {
//                UIApplication.shared.present(websiteViewController, animated: false)
//            }
//        default:
//            break
//        }
//
//        let eventInfo = notification.openedEvent(source: .pushNotification)
//        eventPipeline.addEvent(eventInfo)
        
        return true
    }
}

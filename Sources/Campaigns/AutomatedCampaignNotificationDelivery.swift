//
//  AutomatedCampaignNotificationDelivery.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UserNotifications
import MobileCoreServices
import os

// subscribe to any triggered automated campaigns.  filter by deliverable type (notificadtion only).  use apple scheduled notification + the delay


func scheduleNotificationFromCampaignDeliverable(_ deliverable: NotificationCampaignDeliverable, withDelay delay: TimeInterval? = nil) {
    let notificationContent = deliverable.iosNotificationContent

    let trigger: UNNotificationTrigger?
    if let delay = delay {
        if let delayTime = Calendar.current.date(byAdding: DateComponents(second: Int(delay)), to: Date()) {
            let delayTimeAsComponents = Calendar.current.dateComponents(in: TimeZone.current, from: delayTime)
            
            trigger = UNCalendarNotificationTrigger(dateMatching: delayTimeAsComponents, repeats: false)
        } else {
            os_log("Unable to determine target time for delayed notification, instead emitting it now.")
            trigger = nil
        }
    } else {
        // No trigger needed, we're going to fire it immediately.
        trigger = nil
    }
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: notificationContent,
        trigger: trigger
    )
    
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.add(request) { error in
        if error != nil {
            os_log("Unable to schedule a Rover campaign deliverable notification, because: %s", String(describing: error))
        }
    }
}

fileprivate func fetchAttachment(from attachmentURL: URL) -> UNNotificationAttachment? {
    guard let scheme = attachmentURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
        return nil
    }
    
    typealias DownloadResult = (attachmentLocation: URL?, response: URLResponse?, error: Error?)
    
    let downloadAttachment: (URL) -> DownloadResult = { url in
        var fileLocation: URL?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.downloadTask(with: url) {
            fileLocation = $0
            response = $1
            error = $2
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        
        return (fileLocation, response, error)
    }
    
    let downloadResult = downloadAttachment(attachmentURL)
    
    if let error = downloadResult.error {
        print(error.localizedDescription)
        return nil
    }
    
    guard let attachmentLocation = downloadResult.attachmentLocation else {
        return nil
    }
    
    let utiFromURL: (URL) -> CFString? = { url in
        let ext = url.pathExtension
        if ext.isEmpty {
            return nil
        }
        let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeRetainedValue()
        
        if let uti = uti {
            // return nil if dynamic UTI is assigned, which means the platform could not infer a type from the path extension.
            if String(uti).starts(with: "dyn") {
                return nil
            }
        }
        
        return uti
    }
    
    let utiFromResponse: (URLResponse?) -> CFString? = { response in
        guard let mimeType = (response as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String else {
            return nil
        }
        
        return UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue()
    }
    
    guard let uti = utiFromURL(attachmentURL) ?? utiFromResponse(downloadResult.response) else {
        return nil
    }
    
    let acceptedTypes = [kUTTypeAudioInterchangeFileFormat, kUTTypeWaveformAudio, kUTTypeMP3, kUTTypeMPEG4Audio, kUTTypeJPEG, kUTTypeGIF, kUTTypePNG, kUTTypeMPEG, kUTTypeMPEG2Video, kUTTypeMPEG4, kUTTypeAVIMovie]
    
    guard acceptedTypes.contains(uti) else {
        return nil
    }
    
    let options = [UNNotificationAttachmentOptionsTypeHintKey: uti as String]
    return try? UNNotificationAttachment(identifier: "", url: attachmentLocation, options: options)
}

extension NotificationCampaignDeliverable {
    public var iosNotificationContent: UNNotificationContent {
        let iosNotificationContent = UNMutableNotificationContent()
        
        iosNotificationContent.body = self.body
        if let title = self.title {
            iosNotificationContent.title = title
        }
        if let categoryIdentifier = self.iosCategoryIdentifier {
            iosNotificationContent.categoryIdentifier = categoryIdentifier
        }
        if let threadIdentifier = self.iosThreadIdentifier {
            iosNotificationContent.threadIdentifier = threadIdentifier
        }
        if let sound = self.iosSound {
            iosNotificationContent.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        }
        
        if let attachmentUrlString = self.attachmentUrl {
            if let attachmentUrl = URL(string: attachmentUrlString) {
                if let attachment = fetchAttachment(from: attachmentUrl) {
                    iosNotificationContent.attachments = [attachment]
                }
            }
        }
        
        return iosNotificationContent
    }
}

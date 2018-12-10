//
//  NotificationExtensionHelper.swift
//  RoverAppExtensions
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import MobileCoreServices
import UserNotifications

public class NotificationExtensionHelper {
    let userDefaults: UserDefaults
    
    public init?(appGroup: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroup) else {
            return nil
        }
        self.userDefaults = userDefaults
    }
    
    @discardableResult public func didReceive(_ request: UNNotificationRequest, withContent content: UNMutableNotificationContent) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: content.userInfo, options: []) else {
            clearLastReceivedNotification()
            return false
        }
        
        struct Payload: Decodable {
            struct Rover: Decodable {
                struct Notification: Decodable {
                    var id: ID
                    var campaignID: ID
                    
                    struct Attachment: Decodable {
                        var url: URL
                    }
                    
                    var attachment: Attachment?
                }
                
                var notification: Notification
            }
            
            var rover: Rover
        }
        
        guard let payload = try? JSONDecoder.default.decode(Payload.self, from: data) else {
            
            // This is not a Rover notification – clear the last received notification so we're not taking credit for an influenced open.
            clearLastReceivedNotification()
            return false
        }
        
        let notification = payload.rover.notification
        setLastReceivedNotification(notificationID: notification.id, campaignID: notification.campaignID)
        
        if let attachment = notification.attachment {
            attachMedia(from: attachment.url, to: content)
        }
        
        return true
    }
    
    /*
     * When a notification is received, store its ID and the time it was received in UserDefaults. These values are used by the InfluenceTracker to determine if an influenced open has occured.
     */
    func setLastReceivedNotification(notificationID: ID, campaignID: ID) {
        struct NotificationReceipt: Encodable {
            var notificationID: ID
            var campaignID: ID
            var receivedAt: Date
        }
        
        let now = Date()
        let lastReceivedNotification = NotificationReceipt(notificationID: notificationID, campaignID: campaignID, receivedAt: now)
        
        guard let data = try? PropertyListEncoder().encode(lastReceivedNotification) else {
            clearLastReceivedNotification()
            return
        }
        
        userDefaults.set(data, forKey: "io.rover.lastReceivedNotification")
    }
    
    func clearLastReceivedNotification() {
        userDefaults.removeObject(forKey: "io.rover.lastReceivedNotification")
    }
    
    func attachMedia(from attachmentURL: URL, to content: UNMutableNotificationContent) {
        guard let scheme = attachmentURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return
        }
        
        typealias DownloadResult = (attachmentLocation: URL?, response: URLResponse?, error: Error?)
        
        let downloadAttachment: (URL) -> DownloadResult = { url in
            var fileLocation: URL?
            var response: URLResponse?
            var error: Error?
            
            let semaphore = DispatchSemaphore(value: 0)
            URLSession.shared.downloadTask(with: url, completionHandler: {
                fileLocation = $0
                response = $1
                error = $2
                semaphore.signal()
            }).resume()
            _ = semaphore.wait(timeout: .distantFuture)
            
            return (fileLocation, response, error)
        }
        
        let downloadResult = downloadAttachment(attachmentURL)
        
        if let error = downloadResult.error {
            print(error.localizedDescription)
            return
        }
        
        guard let attachmentLocation = downloadResult.attachmentLocation else {
            return
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
            return
        }
        
        let acceptedTypes = [kUTTypeAudioInterchangeFileFormat, kUTTypeWaveformAudio, kUTTypeMP3, kUTTypeMPEG4Audio, kUTTypeJPEG, kUTTypeGIF, kUTTypePNG, kUTTypeMPEG, kUTTypeMPEG2Video, kUTTypeMPEG4, kUTTypeAVIMovie]
        
        guard acceptedTypes.contains(uti) else {
            return
        }
        
        let options = [UNNotificationAttachmentOptionsTypeHintKey: uti as String]
        if let attachment = try? UNNotificationAttachment(identifier: "", url: attachmentLocation, options: options) {
            content.attachments = [attachment]
        }
    }
}

// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import CoreData
import os.log
import UIKit

extension RCHPersistentContainer {
    /// Returns true if the processed APNs notification user info was handled by Rover.
    func receiveFromPush(userInfo: [AnyHashable: Any]) -> Bool {
        // Push notification delegates are called on main thread, and viewContext uses main queue by default
        assert(Thread.isMainThread, "receiveFromPush should be called on main thread")

        guard let roverObject = userInfo["rover"] as? [AnyHashable: Any], let postObject = roverObject["post"] as? [AnyHashable: Any] else {
            // not a Rover post push.
            return false
        }

        guard let postItem = PostItem.from(dictionary: postObject) else {
            os_log("RCHPersistentContainer.receiveFromPush: received post item, but it's not a valid post item", log: .notifications, type: .error)
            return false
        }

        os_log("RCHPersistentContainer.receiveFromPush: received post item, storing it", log: .notifications, type: .debug)
        
        self.createOrUpdatePost(from: postItem)

        do {
            try self.viewContext.save()
            os_log("RCHPersistentContainer.createOrUpdatePost: successfully saved post received from push", log: .communicationHub, type: .debug)
        } catch {
            os_log("RCHPersistentContainer.createOrUpdatePost: failed to save Core Data context: %@", log: .communicationHub, type: .error, error.localizedDescription)
            return false
        }


        UIApplication.shared.applicationIconBadgeNumber = self.getBadgeCount()

        return true
    }
}

private extension PostItem {
   static func from(dictionary: [AnyHashable: Any]) -> PostItem? {
       guard let idString = dictionary["id"] as? String,
             let id = UUID(uuidString: idString),
             let subject = dictionary["subject"] as? String,
             let previewText = dictionary["previewText"] as? String,
             let receivedAtString = dictionary["receivedAt"] as? String,
             let urlString = dictionary["url"] as? String,
             let url = URL(string: urlString),
             let subscriptionID = dictionary["subscriptionID"] as? String else {
           return nil
       }

       let iso8601Formatter = ISO8601DateFormatter()
       iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

       guard let receivedAt = iso8601Formatter.date(from: receivedAtString) else {
           return nil
       }

       let coverImageURL = (dictionary["coverImageURL"] as? String).flatMap { URL(string: $0) }
       let isRead = dictionary["isRead"] as? Bool ?? false

       return PostItem(
           id: id,
           subject: subject,
           previewText: previewText,
           receivedAt: receivedAt,
           url: url,
           coverImageURL: coverImageURL,
           subscriptionID: subscriptionID,
           isRead: isRead
       )
   }
}

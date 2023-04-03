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
import RoverFoundation
import RoverData

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
    public var conversionTags: [String]
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
    
    public init(id: String, campaignID: String, title: String?, body: String, attachment: NotificationAttachment?, tapBehavior: NotificationTapBehavior, action: Action?, deliveredAt: Date, expiresAt: Date?, isRead: Bool, isNotificationCenterEnabled: Bool, isDeleted: Bool, conversionTags: [String]) {
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
        self.conversionTags = conversionTags
    }
}

extension Notification {
    func openedEvent(source: NotificationSource) -> EventInfo {
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
            "id": id,
            "campaignID": campaignID
        ]
    }
}

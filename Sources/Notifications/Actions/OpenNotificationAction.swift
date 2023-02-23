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

import UIKit
import RoverFoundation
import RoverData

class OpenNotificationAction: Action {
    let eventQueue: EventQueue
    let notification: Notification
    let notificationStore: NotificationStore
    
    typealias ActionProvider = (URL) -> Action?
    
    let presentWebsiteActionProvider: ActionProvider
    
    init(eventQueue: EventQueue, notification: Notification, notificationStore: NotificationStore, presentWebsiteActionProvider: @escaping ActionProvider) {
        self.eventQueue = eventQueue
        self.notification = notification
        self.notificationStore = notificationStore
        self.presentWebsiteActionProvider = presentWebsiteActionProvider

        super.init()
        name = "Open Notification"
    }
    
    override func execute() {
        notificationStore.addNotification(notification)
        
        if !notification.isRead {
            notificationStore.markNotificationRead(notification.id)
        }
        
        switch notification.tapBehavior {
        case .openApp:
            break
        case .openURL(let url):
            DispatchQueue.main.sync {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        case .presentWebsite(let url):
            if let action = presentWebsiteActionProvider(url) {
                produceAction(action)
            }
        }
        
        let eventInfo = notification.openedEvent(source: .pushNotification)
        eventQueue.addEvent(eventInfo)
        finish()
    }
}

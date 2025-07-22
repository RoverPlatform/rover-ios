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

import RoverFoundation
import UserNotifications

class NotificationHandlerService: NotificationHandler {
    let dispatcher: Dispatcher
    let influenceTracker: InfluenceTracker
    
    typealias ActionProvider = (Notification) -> Action?
    
    let actionProvider: ActionProvider
    
    init(dispatcher: Dispatcher, influenceTracker: InfluenceTracker, actionProvider: @escaping ActionProvider) {
        self.dispatcher = dispatcher
        self.actionProvider = actionProvider
        self.influenceTracker = influenceTracker
    }
    
    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
        // The app was opened directly from a push notification. Clear the last received
        // notification from the influence tracker so we don't erroneously track an influenced open.
        influenceTracker.clearLastReceivedNotification()

        // If a Communication Hub post is bundled with the notification, then insert it.
        if let persistentContainer = Rover.shared.resolve(RCHPersistentContainer.self) {
            // discarding the boolean result from receiveFromPush, since getting a post from the notification is only a side-effect for now.
            let _ = persistentContainer.receiveFromPush(userInfo: response.notification.request.content.userInfo)
        }
        
        guard let action = action(for: response) else {
            return false
        }
        
        dispatcher.dispatch(action) {
            DispatchQueue.main.async {
                completionHandler?()
            }
        }
        return true
    }
    
    func action(for response: UNNotificationResponse) -> Action? {
        guard let notification = response.notification.roverNotification else {
            return nil
        }
        return actionProvider(notification)
    }
}

public extension UNNotification {
    /// Decode the Rover notification in the APNS UNNotification, if it contains one.
    var roverNotification: Notification? {
        guard let data = try? JSONSerialization.data(withJSONObject: self.request.content.userInfo, options: []) else {
            return nil
        }
        
        struct Payload: Decodable {
            struct Rover: Decodable {
                var notification: Notification
            }
            
            var rover: Rover
        }
        
        do {
            return try JSONDecoder.default.decode(Payload.self, from: data).rover.notification
        } catch {
            return nil
        }
    }
}

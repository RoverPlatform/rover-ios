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
import RoverData
import UserNotifications

class NotificationAuthorizationManager {
    let authorizationStatus = PersistedValue<Int>(storageKey: "io.rover.RoverNotifications.authorizationStatus")
    let userNotificationCenter = UNUserNotificationCenter.current()
    
    init() { }
}

extension NotificationAuthorizationManager: NotificationsContextProvider {
    var notificationAuthorization: String {
        // Refresh status for _next_ time context is requested
        userNotificationCenter.getNotificationSettings { settings in
            self.authorizationStatus.value = settings.authorizationStatus.rawValue
        }
        
        let authorizationStatus: UNAuthorizationStatus = {
            guard let value = self.authorizationStatus.value, let authorizationStatus = UNAuthorizationStatus(rawValue: value) else {
                return  .notDetermined
            }
            
            return authorizationStatus
        }()
        
        switch authorizationStatus {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .provisional:
            return "provisional"
        #if swift(>=5.3)
        case .ephemeral:
            return "ephemeral"
        #endif
        @unknown default:
            return "notDetermined"
        }
    }
}

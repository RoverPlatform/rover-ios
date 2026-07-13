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
import UIKit

package struct ResolvedIdentifiers: Sendable {
    package let userID: String?
    package let deviceIdentifier: String

    package var queryItems: [URLQueryItem] {
        var items = [URLQueryItem]()
        if let userID { items.append(URLQueryItem(name: "userID", value: userID)) }
        items.append(URLQueryItem(name: "deviceIdentifier", value: deviceIdentifier))
        return items
    }
}

// UIDevice.current requires @MainActor isolation on iOS 17+.
@MainActor
package func syncDeviceIdentifier() -> String? {
    UIDevice.current.identifierForVendor?.uuidString
}

@MainActor
package func resolveIdentifiers(
    userInfoManager: UserInfoManager
) -> ResolvedIdentifiers {
    let userInfo = userInfoManager.currentUserInfo

    let userID: String? = {
        if let id = userInfo["userID"] as? String, !id.isEmpty {
            return id
        }
        let ticketmaster = userInfo["ticketmaster"] as? [String: Any]
        if let id = ticketmaster?["ticketmasterID"] as? String, !id.isEmpty {
            return id
        }
        let seatGeek = userInfo["seatGeek"] as? [String: Any]
        if let id = seatGeek?["seatGeekClientID"] as? String, !id.isEmpty {
            return id
        }
        if let id = seatGeek?["seatGeekID"] as? String, !id.isEmpty {
            return id
        }
        return nil
    }()

    let deviceIdentifier = syncDeviceIdentifier() ?? ""
    return ResolvedIdentifiers(userID: userID, deviceIdentifier: deviceIdentifier)
}

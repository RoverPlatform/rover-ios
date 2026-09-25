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
import RoverData
import RoverFoundation
import os.log

class SeatGeekManager: SeatGeekAuthorizer {
    private let userInfoManager: UserInfoManager

    // NOTE: seatGeekID is actually the CRM ID ("crmID"). The variable name is maintained for backward compatibility.
    private var seatGeekID = PersistedValue<String>(storageKey: "io.rover.SeatGeek")
    private var seatGeekClientID = PersistedValue<String>(storageKey: "io.rover.SeatGeek.seatGeekClientID")

    private var seatGeekUserInfo: [String: String]? {
        var dictionary = [String: String]()

        if let seatGeekID = self.seatGeekID.value {
            dictionary["seatGeekID"] = seatGeekID
        }

        if let clientID = self.seatGeekClientID.value {
            dictionary["seatGeekClientID"] = clientID
        }

        return dictionary.isEmpty ? nil : dictionary
    }

    init(userInfoManager: UserInfoManager) {
        self.userInfoManager = userInfoManager
    }

    // MARK: SeatGeekAuthorizer

    func setSeatGeekID(_ id: String) {
        self.seatGeekID.value = id
        self.seatGeekClientID.value = nil
        updateUserInfo()
    }

    func setSeatGeekIDs(clientID: String, crmID: String) {
        self.seatGeekID.value = crmID
        self.seatGeekClientID.value = clientID

        updateUserInfo()
    }

    func clearCredentials() {
        self.seatGeekID.value = nil
        self.seatGeekClientID.value = nil
        self.userInfoManager.updateUserInfo { attributes in
            attributes.rawValue["seatGeek"] = nil
        }
    }

    private func updateUserInfo() {
        self.userInfoManager.updateUserInfo {
            $0.rawValue["seatGeek"] = seatGeekUserInfo.map { Attributes(rawValue: $0) }
        }

        os_log(
            "SeatGeek IDs have been set.",
            log: .seatgeek,
            type: .info
        )
    }
}

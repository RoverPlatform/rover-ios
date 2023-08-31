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
import os.log
import RoverFoundation
import RoverData

class SeatGeekManager: SeatGeekAuthorizer {
    private let userInfoManager: UserInfoManager
    
    private var seatGeekID = PersistedValue<String>(storageKey: "io.rover.SeatGeek")
    
    private var seatGeekUserInfo: [String: String]? {
        guard let seatGeekID = self.seatGeekID.value else {
            return nil
        }
        
        return ["seatGeekID": seatGeekID]
    }
    
    init(userInfoManager: UserInfoManager) {
        self.userInfoManager = userInfoManager
    }

// MARK: SeatGeekAuthorizer
    
    func setSeatGeekID(_ id: String) {
        self.seatGeekID.value = id
        
        if let userInfo = seatGeekUserInfo {
            self.userInfoManager.updateUserInfo {
                if let existingSeatGeekUserInfo = $0.rawValue["seatGeek"] as? Attributes {
                    // seatgeek data already exists, just clobber it:
                    $0.rawValue["seatGeek"] = Attributes(rawValue: existingSeatGeekUserInfo.rawValue.merging(userInfo) { $1 })
                } else {
                    // seatgeek data does not already exist, so set it:
                    $0.rawValue["seatGeek"] = Attributes(rawValue: userInfo)
                }
            }
            
            os_log("SeatGeekID has been set: %s", log: .general, seatGeekID.value!)
        }
    }
    
    func clearCredentials() {
        self.seatGeekID.value = nil
        self.userInfoManager.updateUserInfo { attributes in
            attributes.rawValue["seatGeek"] = nil
        }
    }
}

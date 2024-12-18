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

class AXSManager: AXSAuthorizer, PrivacyListener {
    private let userInfoManager: UserInfoManager
    private let privacyService: PrivacyService
    
    private var userID = PersistedValue<String>(storageKey: "io.rover.axs")
    private var flashMemberID = PersistedValue<String>(storageKey: "io.rover.axs.flashMemberID")
    private var flashMobileID = PersistedValue<String>(storageKey: "io.rover.axs.flashMobileID")

    private var axsUserInfo: [String: String]? {
        var dictionary = [String: String]()
        
        if let userID = self.userID.value {
            dictionary["userID"] = userID
        }
        
        if let flashMemberID = self.flashMemberID.value {
            dictionary["flashMemberID"] = flashMemberID
        }
        
        if let flashMobileID = self.flashMobileID.value {
            dictionary["flashMobileID"] = flashMobileID
        }
        
        return dictionary
    }

    init(userInfoManager: UserInfoManager, privacyService: PrivacyService) {
        self.userInfoManager = userInfoManager
        self.privacyService = privacyService
    }

// MARK: AxsAuthorizer

    func setUserId(_ id: String) {
        setUserID(id, flashMemberID: nil, flashMobileID: nil)
    }
    
    func setUserID(_ userID: String?, flashMemberID: String?, flashMobileID: String?) {
        guard privacyService.trackingMode == .default else {
            return
        }
        
        guard let userID else {
            clearCredentials()
            return
        }

        self.userID.value = userID
        self.flashMemberID.value = flashMemberID
        self.flashMobileID.value = flashMobileID

        guard let userInfo = axsUserInfo else {
            return
        }
        
        updateUserInfo(userInfo)
        
        os_log("AXS IDs have been set. user ID: %s, flashMemberID: %s, flashMobileID: %s", log: .general, userID, flashMemberID ?? "nil", flashMobileID ?? "nil")
    }

    private func updateUserInfo(_ userInfo: [String: String]) {
        self.userInfoManager.updateUserInfo {
            $0.rawValue["axs"] = Attributes(rawValue: userInfo)
        }
    }

    func clearCredentials() {
        self.userID.value = nil
        self.flashMemberID.value = nil
        self.flashMobileID.value = nil
        self.userInfoManager.updateUserInfo { attributes in
            attributes.rawValue["axs"] = nil
        }
    }
    
    // MARK: Privacy
    
    func trackingModeDidChange(_ trackingMode: PrivacyService.TrackingMode) {
        if(trackingMode != .default) {
            os_log("Tracking disabled, AXS data cleared", log: .axs)
            clearCredentials()
        }
    }
}

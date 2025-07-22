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

class AdobeExperienceManager: AdobeExperienceAuthorizer, PrivacyListener {
    private let userInfoManager: UserInfoManager
    private let privacyService: PrivacyService
    
    private var ecid = PersistedValue<String>(storageKey: "io.rover.AdobeExperience")
    
    init(userInfoManager: UserInfoManager, privacyService: PrivacyService) {
        self.userInfoManager = userInfoManager
        self.privacyService = privacyService
    }

// MARK: AdobeMobileAuthorizer
    
    func setECID(_ ecid: String) {
        guard privacyService.trackingMode == .default else {
            os_log("Adobe Experience ECID set while privacy is in anonymous/anonymized mode, ignored", log: .AdobeExperience, type: .info)
            return
        }
        
        self.ecid.value = ecid
        
        self.userInfoManager.updateUserInfo { userInfo in
            userInfo.rawValue["ecid"] = ecid
        }
        
        os_log("Adobe Experience ECID has been set: %s", log: .general, self.ecid.value!)
    }
    
    func clearCredentials() {
        self.ecid.value = nil
        self.userInfoManager.updateUserInfo { userInfo in
            userInfo.rawValue["ecid"] = nil
        }
    }
    
    // MARK: Privacy
    
    func trackingModeDidChange(_ trackingMode: PrivacyService.TrackingMode) {
        if(trackingMode != .default) {
            os_log("Tracking disabled, Adobe Experience Platform data cleared", log: .AdobeExperience)
            clearCredentials()
        }
    }
}

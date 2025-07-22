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

public extension Rover {
    var userInfoManager: UserInfoManager {
        get {
            resolve(UserInfoManager.self)!
        }
    }
    
    var syncCoordinator: SyncCoordinator {
        get {
            resolve(SyncCoordinator.self)!
        }
    }
    
    var tokenManager: TokenManager {
        get {
            resolve(TokenManager.self)!
        }
    }
    
    var privacyService: PrivacyService {
        get {
            resolve(PrivacyService.self)!
        }
    }
    
    var trackingMode: PrivacyService.TrackingMode {
        get {
            privacyService.trackingMode
        }
        set {
            privacyService.trackingMode = newValue
        }
    }
    
    var authContext: AuthenticationContext {
        get {
            resolve(AuthenticationContext.self)!
        }
    }

    /// Use the Rover Event queue to track custom events into Rover's events pipeline.
    var eventQueue: EventQueue {
        get {
            resolve(EventQueue.self)!
        }
    }

    /// Set a JWT token for the signed-in user, signed (RS256 or better).
    ///
    /// This securely attests to the user's identity to enable additional personalization features.
    ///
    /// Call this method when your user signs in with your account system, and whenever you do your token-refresh cycle.
    func setSDKAuthenticationIDToken(_ token: String?) {
        authContext.setSDKAuthenticationIDToken(token)
    }
    
    /// Clear the SDK authorization token.
    func clearSDKAuthenticationIDToken() {
        authContext.clearSDKAuthenticationIDToken()
    }
    
    /// Register a callback to be called when the Rover SDK needs needs a refreshed SDK authorization token.  When you have obtained a new token, set it as usual with [setSdkAuthorizationIdToken].
    ///
    /// If the token is needed for an interactive user operation (such as fetching an api.rover.io data source), the SDK will wait for 10 seconds before timing out that operation.
    func registerTokenRefreshRequestCallback(_ callback: @escaping () -> Void) {
        authContext.registerTokenRefreshRequestCallback(callback)
    }
}

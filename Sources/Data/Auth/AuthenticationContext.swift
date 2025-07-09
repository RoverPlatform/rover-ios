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

public class AuthenticationContext {
    public private(set) var sdkAuthenticationEnabledDomains = Set<String>(["*.rover.io"])

    private var sdkAuthenticationIDTokenRefreshCallback: () -> Void = {}
    
    private let userDefaults: UserDefaults
    private let idTokenUpdates = AsyncStream<String?>.makeStream()
    
    private static let USER_DEFAULTS_KEY = "io.rover.AuthenticationContext.sdkAuthenticationToken"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func obtainSDKAuthenticationIDToken(checkValidity: Bool = true) async -> String? {
        // if we don't already have a token, then no refresh is necessary.
        guard let existingIDToken = userDefaults.string(forKey: AuthenticationContext.USER_DEFAULTS_KEY) else {
            return nil
        }
        
        if !checkValidity {
            return existingIDToken
        }
        
        // attempt to decode JWT token, checking for exp.
        guard let exp = getJwtExpiry(jwt: existingIDToken) else {
            os_log("Existing JWT token is invalid, cannot decode expiry. Keeping it.", log: .auth, type: .error)
            return existingIDToken
        }
        
        if exp < Date(timeIntervalSinceNow: 60) {
            os_log("SDK Authentication ID Token expired or about to expire, and needs to be refreshed, holding request waiting for new token to be set.\nPlease call Rover.shared.setSDKAuthenticationIDToken() with the new token within 10s.", log: .auth, type: .info)
            return await requestAndAwaitNewToken()
        } else {
            os_log("SDK Authentication ID Token is still valid. %{public}@", log: .auth, type: .debug, exp as CVarArg)
        }
        
        return existingIDToken
    }
    
    public func peekSDKAuthenticationIDToken() -> String? {
        userDefaults.string(forKey: AuthenticationContext.USER_DEFAULTS_KEY)
    }
    
    public func setSDKAuthenticationIDToken(_ token: String?) {
        
        if let token = token {
            userDefaults.set(token, forKey: AuthenticationContext.USER_DEFAULTS_KEY)
        } else {
            userDefaults.removeObject(forKey: AuthenticationContext.USER_DEFAULTS_KEY)
        }
        userDefaults.synchronize()
        
        // Emit the new token to the stream
        Task {
            idTokenUpdates.continuation.yield(token)
        }
        
        guard let token = token, let expiry = getJwtExpiry(jwt: token) else {
            if token != nil {
                os_log("Possibly invalid JWT ID token set.", log: .auth, type: .error)
            }
            return
        }
        
        let timeUntilExpiry = expiry.timeIntervalSince(Date())
        if timeUntilExpiry < 0 {
            os_log("SDK Authentication ID Token has been set, but it is already expired. It expired %{public}fs ago.", log: .auth, type: .error, -timeUntilExpiry)
        } else {
            os_log("New SDK Authentication JWT ID Token set, with an expiry that is %{public}fs in the future.", log: .auth, type: .info, timeUntilExpiry)
        }
    }
    
    public func clearSDKAuthenticationIDToken() {
        setSDKAuthenticationIDToken(nil)
    }
    
    public func registerTokenRefreshRequestCallback(_ callback: @escaping () -> Void) {
        self.sdkAuthenticationIDTokenRefreshCallback = callback
    }
    
    /// Wait for a call to Rover.shared.setSDKAuthorizationIDToken(), or timeout.
    private func requestAndAwaitNewToken() async -> String? {
        // Fire a request for a token refresh on the main thread
        await MainActor.run {
            sdkAuthenticationIDTokenRefreshCallback()
        }
        
        // Wait for the setter to be called, with a timeout.
        do {
            let newToken = try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    for await token in self.idTokenUpdates.stream.prefix(1) {
                        os_log("Token arrived while waiting, continuing.", log: .auth)
                        return token
                    }
                    return nil
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    throw TimeoutError()
                }
                
                // Return the first completed task (either the token or a timeout)
                let token =  try await group.next() ?? nil
                group.cancelAll()
                return token
            }
            return newToken
        } catch {
            os_log("Rover.shared.setSDKAuthenticationIDToken() was not called within 10 seconds. Omitting token from request.", log: .auth, type: .error)
            return nil
        }
    }
    
    public func enableSDKAuthIDTokenRefreshForDomain(pattern: String) {
        sdkAuthenticationEnabledDomains.insert(pattern)
    }
}

/// Decode a JWT token and return the expiry time.
///
/// Note this does not check the signature. The only task is to check if we should request a new token.
private func getJwtExpiry(jwt: String) -> Date? {
    let parts = jwt.split(separator: ".")
    guard parts.count == 3 else {
        return nil
    }
    
    let paddedBase64 = padBase64(String(parts[1]))
    
    guard let decodedData = Data(base64Encoded: paddedBase64) else {
        return nil
    }
    
    do {
        if let json = try JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
           let expValue = json["exp"] as? TimeInterval {
            return Date(timeIntervalSince1970: expValue)
        }
    } catch {
        return nil
    }
    
    return nil
}

/// Helper function to convert urlbase64 to regular base64, which the implementation of base64 in Swift Foundation expects.
private func padBase64(_ base64: String) -> String {
    var padded = base64
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    
    let remainder = padded.count % 4
    if remainder > 0 {
        padded = padded.padding(toLength: padded.count + 4 - remainder,
                               withPad: "=",
                               startingAt: 0)
    }
    
    return padded
}

/// Custom error for developer to call ``Rover.shared.setSDKAuthenticationIDToken()``
private struct TimeoutError: LocalizedError {
    var errorDescription: String? { "Rover.shared.setSDKAuthenticationIDToken() not called within 10 seconds" }
}

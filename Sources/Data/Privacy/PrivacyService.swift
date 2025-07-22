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

/// This object is responsible for the global privacy settings of the Rover SDK.
public class PrivacyService: PrivacyContextProvider {
    public enum TrackingMode: String, Identifiable, CaseIterable {
        public static var allCases: [PrivacyService.TrackingMode] = [.default, .anonymized]
        
        case `default`
        @available(*, deprecated, message: "Use TrackingMode.anonymized")
        case anonymous
        case anonymized
        
        public var id: Self { self }
    }
    
    public var trackingMode: TrackingMode {
        get {
            let value = UserDefaults.standard.string(forKey: "io.rover.TrackingMode") ?? "default"
            return TrackingMode(rawValue: value) ?? .default
        }
        set {
            let oldValue = trackingMode
            UserDefaults.standard.set(newValue.rawValue, forKey: "io.rover.TrackingMode")
            
            os_log("Privacy tracking mode changed from %s to %s", log: .general, type: .info, oldValue.rawValue, newValue.rawValue)
            
            // re-emit to listeners
            refreshAllListeners()
        }
    }
    
    var trackingModeListeners: [PrivacyListener] = []
    
    public func registerTrackingEnabledListener(_ listener: PrivacyListener) {
        trackingModeListeners.append(listener)
        listener.trackingModeDidChange(trackingMode)
    }

    public func registerTrackingEnabledChangedCallback(_ callback: @escaping (TrackingMode) -> Void) {
        registerTrackingEnabledListener(
            PrivacyCallbackListener(callback: callback)
        )
    }
    
    /// Meant to be called after didAssemble.
    func refreshAllListeners() {
        trackingModeListeners.forEach { $0.trackingModeDidChange(trackingMode) }
    }
    
    // MARK: Context Provider
    
    public var trackingModeString: String? {
        trackingMode.rawValue
    }
}

public protocol PrivacyListener {
    /// Notify this listener that tracking mode has changed.
    func trackingModeDidChange(_ trackingMode: PrivacyService.TrackingMode)
}

private class PrivacyCallbackListener: PrivacyListener {
    let callback: (PrivacyService.TrackingMode) -> Void
    
    internal init(callback: @escaping (PrivacyService.TrackingMode) -> Void) {
        self.callback = callback
    }
    
    func trackingModeDidChange(_ trackingMode: PrivacyService.TrackingMode) {
        callback(trackingMode)
    }
}

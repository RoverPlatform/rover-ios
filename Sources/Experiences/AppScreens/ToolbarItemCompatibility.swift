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

/// Whether navigation-bar buttons must draw the V2 "compatibility" chrome — a
/// `.thinMaterial` circle behind the glyph — instead of relying on the iOS 26
/// navigation bar's native liquid-glass background. Applies to both the Hub's V2
/// SwiftUI toolbar and the V3 App Screens UIKit chrome.
///
/// Mirrors what UIKit and SwiftUI actually do, in their order of precedence:
///
/// 1. Below iOS 26 there is no native glass background, so compatibility chrome.
/// 2. Otherwise the app opts out of the redesign with the
///    `UIDesignRequiresCompatibility` Info.plist flag — unless the hidden
///    `com.apple.SwiftUI.IgnoreSolariumOptOut` default is set, which makes the
///    frameworks ignore that opt-out and render the redesign anyway.
/// 3. Otherwise, native.
///
/// Evaluated once per process, as the frameworks themselves resolve this at launch:
/// the OS version and the Info.plist flag are immutable, and writing the defaults key
/// takes effect on the next launch, not this one.
///
/// `package` (not public): the single source of truth shared with
/// `RoverNotifications`, whose SwiftUI `CompatibleInboxToolbarButton` (the Hub path)
/// applies the same gate. Keeps the UIKit App Screens close button and the SwiftUI
/// Hub toolbar in lockstep. Rover Bench reads it through
/// `@_spi(BenchSupport) Rover.toolbarItemsRequireCompatibilityChrome` so its settings
/// row reports this value rather than a second copy of the rule.
///
/// The hidden key's name says SwiftUI, but it is not SwiftUI-only. Confirmed on iOS 26
/// (iPhone 17 Pro simulator, Xcode 26.5) with the opt-out plist shipped: writing it
/// flips UIKit's chrome too — `UITabBar` becomes the floating capsule, and a bare
/// `UINavigationBar` changes both its background material and its height. So this one
/// resolution is the honest answer for UIKit and SwiftUI surfaces alike. Re-confirm on
/// each iOS major: the key is private, and if a release ever splits the two, toolbar
/// *items* (SwiftUI-drawn in both the Hub and App Screens) are what this value must
/// keep tracking.
package let toolbarItemsRequireCompatibilityChrome: Bool = {
    let isRedesignAvailable: Bool
    if #available(iOS 26, *) {
        isRedesignAvailable = true
    } else {
        isRedesignAvailable = false
    }

    let requiresCompatibility =
        Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool ?? false
    let ignoresOptOut = UserDefaults.standard.bool(forKey: "com.apple.SwiftUI.IgnoreSolariumOptOut")

    return resolveToolbarItemsRequireCompatibilityChrome(
        isRedesignAvailable: isRedesignAvailable,
        requiresCompatibility: requiresCompatibility,
        ignoresOptOut: ignoresOptOut
    )
}()

/// The resolution above, separated from where its inputs come from so the precedence
/// can be tested.
package func resolveToolbarItemsRequireCompatibilityChrome(
    isRedesignAvailable: Bool,
    requiresCompatibility: Bool,
    ignoresOptOut: Bool
) -> Bool {
    guard isRedesignAvailable else { return true }
    return requiresCompatibility && !ignoresOptOut
}

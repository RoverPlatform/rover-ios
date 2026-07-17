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
/// Evaluated once per process: both inputs (the `UIDesignRequiresCompatibility`
/// Info.plist flag and the OS version) are immutable after launch. `true` when the
/// app opts into compatibility rendering via the plist key, OR when running below
/// iOS 26 (where the native glass background does not exist).
///
/// `package` (not public): the single source of truth shared with
/// `RoverNotifications`, whose SwiftUI `CompatibleInboxToolbarButton` (the Hub path)
/// applies the same gate, following the `AppScreensRootBarItem` cross-module
/// precedent. Keeps the UIKit App Screens bar buttons and the SwiftUI Hub toolbar
/// in lockstep.
package let toolbarItemsRequireCompatibilityChrome: Bool = {
    let requiresCompatibility =
        Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool ?? false
    if requiresCompatibility { return true }
    if #available(iOS 26, *) { return false }
    return true
}()

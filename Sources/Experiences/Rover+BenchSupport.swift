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

/// Hooks for Rover Bench, our internal test harness.
///
/// Guarded by `@_spi(BenchSupport)`, the same as `RoverData`'s config-override hook:
/// importers see none of this unless they write
/// `@_spi(BenchSupport) import RoverExperiences`.
@_spi(BenchSupport)
public extension Rover {
    /// The SDK's own answer to "is this process drawing compatibility chrome or the iOS 26
    /// redesign?" — the resolution behind every `CompatibleToolbarButton` and App Screens
    /// close button.
    ///
    /// Exposed for Bench's Liquid Glass settings row, which shows the *effective* state of
    /// a setting whose stored value is only a request. The row reads this rather than
    /// recomputing it, so there is one copy of a precedence rule that exists precisely because
    /// the real one is surprising (ship the plist opt-out permanently; a hidden default turns
    /// the redesign back on). Two copies would drift, and the row's whole job is to be
    /// believed.
    ///
    /// Read-only, and resolved once per process — see
    /// `toolbarItemsRequireCompatibilityChrome` for why that matters.
    var toolbarItemsRequireCompatibilityChrome: Bool {
        RoverExperiences.toolbarItemsRequireCompatibilityChrome
    }
}

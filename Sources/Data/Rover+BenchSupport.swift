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
/// Guarded by `@_spi(BenchSupport)`: importers see none of this unless they write
/// `@_spi(BenchSupport) import RoverData`, so it stays out of integrator
/// autocomplete and out of the public API surface.
@_spi(BenchSupport)
public extension Rover {
    /// In-memory overrides layered over the backend-provisioned Hub configuration and
    /// the `/home` experience URL.
    ///
    /// Overrides survive backend re-syncs (config re-syncs on every Hub appearance)
    /// but are never persisted — a relaunch starts clean. Setting them takes effect
    /// immediately, so they can be set at any point in the app's lifetime.
    ///
    /// ```swift
    /// Rover.shared.configOverrides = RoverConfigOverrides(
    ///     isHomeEnabled: .value(true),
    ///     deeplink: .unset
    /// )
    /// ```
    @MainActor
    var configOverrides: RoverConfigOverrides {
        get {
            resolve(ConfigManager.self)!.overrides
        }
        set {
            applyConfigOverrides(
                newValue,
                configManager: resolve(ConfigManager.self)!,
                homeViewManager: resolve(HomeViewManager.self)!
            )
        }
    }
}

/// Applies overrides across the managers that consume them, separated from the DI
/// lookup so it can be tested.
///
/// Turning the home view on is the one case that needs more than a re-publish:
/// `HubContentView` only starts the `/home` fetch from its `onAppear`, which has
/// already run by the time an override lands, so a Hub that is on screen with the
/// home view disabled would sit on the inbox fallback until it reappeared.
@MainActor
func applyConfigOverrides(
    _ overrides: RoverConfigOverrides,
    configManager: ConfigManager,
    homeViewManager: HomeViewManager
) {
    let wasHomeEnabled = configManager.config.hub.isHomeEnabled

    configManager.overrides = overrides
    homeViewManager.experienceURLOverride = overrides.homeViewURL

    guard !wasHomeEnabled, configManager.config.hub.isHomeEnabled else { return }
    homeViewManager.refresh()
}

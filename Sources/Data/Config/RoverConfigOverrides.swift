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

/// A single overridable value, layered over whatever the backend provided.
///
/// The three cases are deliberately distinct: "leave the backend alone" and "force
/// this field to be absent" are different intents, and a plain `T?` cannot express
/// both.
@_spi(BenchSupport)
public enum Override<Value>: Equatable where Value: Equatable {
    /// Pass the backend value through untouched.
    case noOverride
    /// Force the field to the value the SDK uses when the backend omits it — `nil`
    /// for optional fields, the `RoverConfig` default for non-optional ones.
    case unset
    /// Force the field to this value, whatever the backend provided.
    case value(Value)

    /// Resolves this override against an optional backend value.
    func resolved(from backendValue: Value?) -> Value? {
        switch self {
        case .noOverride: return backendValue
        case .unset: return nil
        case .value(let value): return value
        }
    }

    /// Resolves this override against a non-optional backend value.
    ///
    /// - Parameters:
    ///   - backendValue: The value the backend provided.
    ///   - absentValue: The value to use for `.unset`, i.e. what the field would be
    ///     had the backend never provided it.
    func resolved(from backendValue: Value, whenUnset absentValue: Value) -> Value {
        switch self {
        case .noOverride: return backendValue
        case .unset: return absentValue
        case .value(let value): return value
        }
    }
}

/// In-memory overrides layered over the backend-provisioned Hub configuration.
///
/// Exists for Rover Bench, which needs to drive the SDK through configurations the
/// backend will not hand out on demand. The overrides are a *layer*, not a
/// replacement: config re-syncs on every Hub appearance, and each publish applies
/// these overrides over the freshly-fetched backend value. They are never persisted
/// by the SDK — a relaunch starts with no overrides, and the SDK's own caches always
/// hold the unmodified backend response.
///
/// Set them through `Rover.shared.configOverrides`.
///
/// - SeeAlso: `ConfigManager` for the `RoverConfig` fields, `HomeViewManager` for
///   `homeViewURL`.
@_spi(BenchSupport)
public struct RoverConfigOverrides: Equatable {
    /// Overrides `RoverConfig.hub.isHomeEnabled`.
    public var isHomeEnabled: Override<Bool>
    /// Overrides `RoverConfig.hub.isInboxEnabled`.
    public var isInboxEnabled: Override<Bool>
    /// Overrides `RoverConfig.hub.deeplink`.
    public var deeplink: Override<URL>
    /// Overrides `RoverConfig.colorScheme`.
    public var colorScheme: Override<HubColorScheme>
    /// Overrides `RoverConfig.accentColor`, a `#RRGGBB` hex string.
    public var accentColor: Override<String>
    /// Overrides the home view experience URL fetched from `/home`.
    ///
    /// Consumed by `HomeViewManager` rather than `ConfigManager`; it is carried here
    /// so that everything Bench can override travels as one value.
    public var homeViewURL: Override<URL>

    public init(
        isHomeEnabled: Override<Bool> = .noOverride,
        isInboxEnabled: Override<Bool> = .noOverride,
        deeplink: Override<URL> = .noOverride,
        colorScheme: Override<HubColorScheme> = .noOverride,
        accentColor: Override<String> = .noOverride,
        homeViewURL: Override<URL> = .noOverride
    ) {
        self.isHomeEnabled = isHomeEnabled
        self.isInboxEnabled = isInboxEnabled
        self.deeplink = deeplink
        self.colorScheme = colorScheme
        self.accentColor = accentColor
        self.homeViewURL = homeViewURL
    }

    /// Applies the config overrides over a backend configuration.
    ///
    /// - Parameter config: The configuration as the backend provided it.
    /// - Returns: The configuration to publish.
    func applied(to config: RoverConfig) -> RoverConfig {
        let defaults = RoverConfig.Hub()
        var result = config
        result.hub.isHomeEnabled = isHomeEnabled.resolved(
            from: config.hub.isHomeEnabled,
            whenUnset: defaults.isHomeEnabled
        )
        result.hub.isInboxEnabled = isInboxEnabled.resolved(
            from: config.hub.isInboxEnabled,
            whenUnset: defaults.isInboxEnabled
        )
        result.hub.deeplink = deeplink.resolved(from: config.hub.deeplink)
        result.colorScheme = colorScheme.resolved(from: config.colorScheme)
        result.accentColor = accentColor.resolved(from: config.accentColor)
        return result
    }
}

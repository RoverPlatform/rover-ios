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

/// Manager for SDK configuration.
///
/// Manages the active configuration for the SDK, loading from backend-provided
/// configuration with a default fallback when no backend config is available.
@MainActor
public class ConfigManager: ObservableObject {
    /// The currently active configuration.
    ///
    /// Returns the backend configuration if available, otherwise returns default values,
    /// with any Bench overrides applied on top.
    @Published public private(set) var config: RoverConfig

    /// The configuration exactly as the backend provided it, before overrides.
    ///
    /// This — never the overridden value — is what gets persisted.
    private var backendConfig: RoverConfig

    /// In-memory overrides layered over `backendConfig` on every publish.
    ///
    /// Held here rather than in the Bench app so that a backend re-sync cannot wash
    /// them away. Setting them re-publishes immediately.
    @_spi(BenchSupport)
    public var overrides = RoverConfigOverrides() {
        didSet {
            guard overrides != oldValue else { return }
            config = overrides.applied(to: backendConfig)
            os_log("Config overrides applied", log: .config, type: .debug)
        }
    }

    private let userDefaults: UserDefaults

    private enum StorageKeys {
        static let backendConfig = "io.rover.hub.config"
    }

    /// Creates a new configuration manager.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence.
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.backendConfig = Self.loadBackendConfig(from: userDefaults) ?? RoverConfig()
        self.config = self.backendConfig
    }

    /// Updates the configuration from the backend.
    ///
    /// Saves the provided configuration and activates it immediately, with any
    /// overrides applied over top.
    ///
    /// - Parameter newConfig: The configuration received from the backend.
    public func updateFromBackend(_ newConfig: RoverConfig) {
        saveBackendConfig(newConfig)
        backendConfig = newConfig
        config = overrides.applied(to: newConfig)
        os_log("Backend config saved and activated", log: .config, type: .debug)
    }

    // MARK: - Private

    private static func loadBackendConfig(from userDefaults: UserDefaults) -> RoverConfig? {
        guard let data = userDefaults.data(forKey: StorageKeys.backendConfig) else {
            return nil
        }
        do {
            let config = try JSONDecoder().decode(RoverConfig.self, from: data)
            os_log("Loading backend config", log: .config, type: .debug)
            return config
        } catch {
            os_log(
                "Failed to decode backend config: %{public}@",
                log: .config,
                type: .error,
                error.localizedDescription)
            return nil
        }
    }

    private func saveBackendConfig(_ newConfig: RoverConfig) {
        do {
            let data = try JSONEncoder().encode(newConfig)
            userDefaults.set(data, forKey: StorageKeys.backendConfig)
        } catch {
            os_log(
                "Failed to encode config: %{public}@",
                log: .config,
                type: .error,
                error.localizedDescription)
        }
    }
}

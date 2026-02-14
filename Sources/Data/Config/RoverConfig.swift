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

/// Configuration for the Hub features and appearance.
///
/// This struct defines the configuration options available for the Hub, including
/// feature flags, UI customization, and navigation settings.
///
/// - SeeAlso: `ConfigManager` for managing configuration sources and override mode
/// - SeeAlso: `HubCoordinator` for SwiftUI type conversions (hex -> Color, colorScheme -> ColorScheme)
public struct RoverConfig: Codable, Equatable {
    public struct Hub: Codable, Equatable {
        public var isHomeEnabled: Bool
        public var isInboxEnabled: Bool
        public var isSettingsViewEnabled: Bool
        public var deeplink: URL?

        public init(
            isHomeEnabled: Bool = false,
            isInboxEnabled: Bool = true,
            isSettingsViewEnabled: Bool = false,
            deeplink: URL? = nil
        ) {
            self.isHomeEnabled = isHomeEnabled
            self.isInboxEnabled = isInboxEnabled
            self.isSettingsViewEnabled = isSettingsViewEnabled
            self.deeplink = deeplink
        }
    }

    public var hub: Hub
    public var colorScheme: HubColorScheme?
    public var accentColor: String?

    public init(
        hub: Hub = Hub(),
        colorScheme: HubColorScheme? = nil,
        accentColor: String? = nil
    ) {
        self.hub = hub
        self.colorScheme = colorScheme
        self.accentColor = accentColor
    }
}

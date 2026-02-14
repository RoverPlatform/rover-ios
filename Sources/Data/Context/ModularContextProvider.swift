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

class ModularContextProvider {
    weak var privacyContextProvider: PrivacyContextProvider?
    weak var darkModeContextProvider: DarkModeContextProvider?
    weak var debugContextProvider: DebugContextProvider?
    weak var localeContextProvider: LocaleContextProvider?
    weak var locationContextProvider: LocationContextProvider?
    weak var notificationsContextProvider: NotificationsContextProvider?
    weak var pushTokenContextProvider: PushTokenContextProvider?
    weak var liveActivityTokensContextProvider: LiveActivityTokensContextProvider?
    weak var reachabilityContextProvider: ReachabilityContextProvider?
    weak var staticContextProvider: StaticContextProvider?
    weak var telephonyContextProvider: TelephonyContextProvider?
    weak var timeZoneContextProvider: TimeZoneContextProvider?
    weak var userInfoContextProvider: UserInfoContextProvider?
    weak var conversionsContextProvider: ConversionsContextProvider?
    weak var appLastSeenContextProvider: AppLastSeenContextProvider?

    init(
        privacyContextProvider: PrivacyContextProvider?,
        darkModeContextProvider: DarkModeContextProvider?,
        debugContextProvider: DebugContextProvider?,
        locationContextProvider: LocationContextProvider?,
        localeContextProvider: LocaleContextProvider?,
        notificationsContextProvider: NotificationsContextProvider?,
        pushTokenContextProvider: PushTokenContextProvider?,
        liveActivityTokensContextProvider: LiveActivityTokensContextProvider?,
        reachabilityContextProvider: ReachabilityContextProvider?,
        staticContextProvider: StaticContextProvider,
        telephonyContextProvider: TelephonyContextProvider?,
        timeZoneContextProvider: TimeZoneContextProvider?,
        userInfoContextProvider: UserInfoContextProvider?,
        conversionsContextProvider: ConversionsContextProvider?,
        appLastSeenContextProvider: AppLastSeenContextProvider?
    ) {
        self.privacyContextProvider = privacyContextProvider
        self.darkModeContextProvider = darkModeContextProvider
        self.debugContextProvider = debugContextProvider
        self.localeContextProvider = localeContextProvider
        self.locationContextProvider = locationContextProvider
        self.notificationsContextProvider = notificationsContextProvider
        self.pushTokenContextProvider = pushTokenContextProvider
        self.liveActivityTokensContextProvider = liveActivityTokensContextProvider
        self.reachabilityContextProvider = reachabilityContextProvider
        self.staticContextProvider = staticContextProvider
        self.telephonyContextProvider = telephonyContextProvider
        self.timeZoneContextProvider = timeZoneContextProvider
        self.userInfoContextProvider = userInfoContextProvider
        self.conversionsContextProvider = conversionsContextProvider
        self.appLastSeenContextProvider = appLastSeenContextProvider
    }
}

extension ModularContextProvider: ContextProvider {
    var context: Context {
        return Context(
            trackingMode: self.privacyContextProvider?.trackingModeString,
            isDarkModeEnabled: self.darkModeContextProvider?.isDarkModeEnabled,
            localeLanguage: self.localeContextProvider?.localeLanguage,
            localeRegion: self.localeContextProvider?.localeRegion,
            localeScript: self.localeContextProvider?.localeScript,
            isLocationServicesEnabled: self.locationContextProvider?.isLocationServicesEnabled,
            location: self.locationContextProvider?.location,
            locationAuthorization: self.locationContextProvider?.locationAuthorization,
            notificationAuthorization: self.notificationsContextProvider?.notificationAuthorization,
            pushToken: self.pushTokenContextProvider?.pushToken,
            liveActivityTokens: self.liveActivityTokensContextProvider?.liveActivityTokens,
            isCellularEnabled: self.reachabilityContextProvider?.isCellularEnabled,
            isWifiEnabled: self.reachabilityContextProvider?.isWifiEnabled,
            appBadgeNumber: self.staticContextProvider?.appBadgeNumber,
            appBuild: self.staticContextProvider?.appBuild,
            appIdentifier: self.staticContextProvider?.appIdentifier,
            appVersion: self.staticContextProvider?.appVersion,
            buildEnvironment: self.staticContextProvider?.buildEnvironment,
            deviceIdentifier: self.staticContextProvider?.deviceIdentifier,
            deviceManufacturer: self.staticContextProvider?.deviceManufacturer,
            deviceModel: self.staticContextProvider?.deviceModel,
            deviceName: self.staticContextProvider?.deviceName,
            operatingSystemName: self.staticContextProvider?.operatingSystemName,
            operatingSystemVersion: self.staticContextProvider?.operatingSystemVersion,
            screenHeight: self.staticContextProvider?.screenHeight,
            screenWidth: self.staticContextProvider?.screenWidth,
            sdkVersion: self.staticContextProvider?.sdkVersion,
            carrierName: self.telephonyContextProvider?.carrierName,
            radio: self.telephonyContextProvider?.radio,
            isTestDevice: self.debugContextProvider?.isTestDevice,
            timeZone: self.timeZoneContextProvider?.timeZone,
            userInfo: self.userInfoContextProvider?.userInfo,
            conversions: self.conversionsContextProvider?.conversions,
            lastSeen: self.appLastSeenContextProvider?.appLastSeen
        )
    }
}

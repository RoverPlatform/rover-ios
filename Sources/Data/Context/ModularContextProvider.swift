//
//  ModularContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

class ModularContextProvider {
    weak var adSupportContextProvider: AdSupportContextProvider?
    weak var bluetoothContextProvider: BluetoothContextProvider?
    weak var debugContextProvider: DebugContextProvider?
    weak var localeContextProvider: LocaleContextProvider?
    weak var locationContextProvider: LocationContextProvider?
    weak var notificationsContextProvider: NotificationsContextProvider?
    weak var pushTokenContextProvider: PushTokenContextProvider?
    weak var reachabilityContextProvider: ReachabilityContextProvider?
    weak var staticContextProvider: StaticContextProvider?
    weak var telephonyContextProvider: TelephonyContextProvider?
    weak var timeZoneContextProvider: TimeZoneContextProvider?
    weak var userInfoContextProvider: UserInfoContextProvider?
    
    init(
        adSupportContextProvider: AdSupportContextProvider?,
        bluetoothContextProvider: BluetoothContextProvider?,
        debugContextProvider: DebugContextProvider?,
        locationContextProvider: LocationContextProvider?,
        localeContextProvider: LocaleContextProvider?,
        notificationsContextProvider: NotificationsContextProvider?,
        pushTokenContextProvider: PushTokenContextProvider?,
        reachabilityContextProvider: ReachabilityContextProvider?,
        staticContextProvider: StaticContextProvider,
        telephonyContextProvider: TelephonyContextProvider?,
        timeZoneContextProvider: TimeZoneContextProvider?,
        userInfoContextProvider: UserInfoContextProvider?
    ) {
        self.adSupportContextProvider = adSupportContextProvider
        self.bluetoothContextProvider = bluetoothContextProvider
        self.debugContextProvider = debugContextProvider
        self.localeContextProvider = localeContextProvider
        self.locationContextProvider = locationContextProvider
        self.notificationsContextProvider = notificationsContextProvider
        self.pushTokenContextProvider = pushTokenContextProvider
        self.reachabilityContextProvider = reachabilityContextProvider
        self.staticContextProvider = staticContextProvider
        self.telephonyContextProvider = telephonyContextProvider
        self.timeZoneContextProvider = timeZoneContextProvider
        self.userInfoContextProvider = userInfoContextProvider
    }
}

extension ModularContextProvider: ContextProvider {
    var context: Context {
        return Context(
            advertisingIdentifier: self.adSupportContextProvider?.advertisingIdentifier,
            isBluetoothEnabled: self.bluetoothContextProvider?.isBluetoothEnabled,
            localeLanguage: self.localeContextProvider?.localeLanguage,
            localeRegion: self.localeContextProvider?.localeRegion,
            localeScript: self.localeContextProvider?.localeScript,
            isLocationServicesEnabled: self.locationContextProvider?.isLocationServicesEnabled,
            location: self.locationContextProvider?.location,
            locationAuthorization: self.locationContextProvider?.locationAuthorization,
            notificationAuthorization: self.notificationsContextProvider?.notificationAuthorization,
            pushToken: self.pushTokenContextProvider?.pushToken,
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
            userInfo: self.userInfoContextProvider?.userInfo
        )
    }
}

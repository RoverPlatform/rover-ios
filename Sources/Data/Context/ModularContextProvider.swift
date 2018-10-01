//
//  ModularContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

class ModularContextProvider {
    let bluetoothContextProvider: BluetoothContextProvider?
    let debugContextProvider: DebugContextProvider?
    let localeContextProvider: LocaleContextProvider?
    let locationContextProvider: LocationContextProvider?
    let notificationsContextProvider: NotificationsContextProvider?
    let pushTokenContextProvider: PushTokenContextProvider?
    let reachabilityContextProvider: ReachabilityContextProvider?
    let staticContextProvider: StaticContextProvider
    let telephonyContextProvider: TelephonyContextProvider?
    let timeZoneContextProvider: TimeZoneContextProvider?
    let userInfoContextProvider: UserInfoContextProvider?
    
    init(
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
        userInfoContextProvider: UserInfoContextProvider?) {
        
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
            appBadgeNumber: self.staticContextProvider.appBadgeNumber,
            appBuild: self.staticContextProvider.appBuild,
            appIdentifier: self.staticContextProvider.appIdentifier,
            appVersion: self.staticContextProvider.appVersion,
            buildEnvironment: self.staticContextProvider.buildEnvironment,
            deviceIdentifier: self.staticContextProvider.deviceIdentifier,
            deviceManufacturer: self.staticContextProvider.deviceManufacturer,
            deviceModel: self.staticContextProvider.deviceModel,
            deviceName: self.staticContextProvider.deviceName,
            operatingSystemName: self.staticContextProvider.operatingSystemName,
            operatingSystemVersion: self.staticContextProvider.operatingSystemVersion,
            screenHeight: self.staticContextProvider.screenHeight,
            screenWidth: self.staticContextProvider.screenWidth,
            sdkVersion: self.staticContextProvider.sdkVersion,
            carrierName: self.telephonyContextProvider?.carrierName,
            radio: self.telephonyContextProvider?.radio,
            isTestDevice: self.debugContextProvider?.isTestDevice,
            timeZone: self.timeZoneContextProvider?.timeZone,
            userInfo: self.userInfoContextProvider?.userInfo
        )
    }
}

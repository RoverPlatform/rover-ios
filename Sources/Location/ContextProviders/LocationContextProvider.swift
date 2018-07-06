//
//  LocationContextProvider.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

struct LocationContextProvider: ContextProvider {
    var locationAuthorization: String {
        let authorizationStatus: String
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways:
            authorizationStatus = "authorizedAlways"
        case .authorizedWhenInUse:
            authorizationStatus = "authorizedWhenInUse"
        case .denied:
            authorizationStatus = "denied"
        case .notDetermined:
            authorizationStatus = "notDetermined"
        case .restricted:
            authorizationStatus = "restricted"
        }
        
        return authorizationStatus
    }
    
    var isLocationServicesEnabled: Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.locationAuthorization = locationAuthorization
        nextContext.isLocationServicesEnabled = isLocationServicesEnabled
        return nextContext
    }
}


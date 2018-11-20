//
//  CLLocation.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocation {
    public func context(placemark: CLPlacemark?) -> DeviceSnapshot.Location {
        let coordinate = DeviceSnapshot.Location.Coordinate(
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude
        )
        
        let address: DeviceSnapshot.Location.Address? = {
            guard let placemark = placemark else {
                return nil
            }
            
            return DeviceSnapshot.Location.Address(
                street: placemark.thoroughfare,
                city: placemark.locality,
                state: placemark.administrativeArea,
                postalCode: placemark.postalCode,
                country: placemark.country,
                isoCountryCode: placemark.isoCountryCode,
                subAdministrativeArea: placemark.administrativeArea,
                subLocality: placemark.subLocality
            )
        }()
        
        return DeviceSnapshot.Location(
            coordinate: coordinate,
            altitude: self.altitude,
            horizontalAccuracy: self.horizontalAccuracy,
            verticalAccuracy: self.verticalAccuracy,
            address: address,
            timestamp: self.timestamp
        )
    }
}

//
//  CLLocation.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocation {
    public func context(placemark: CLPlacemark?) -> LocationSnapshot {
        let coordinate = CoordinateSnapshot(
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude
        )
        
        let address: AddressSnapshot? = {
            guard let placemark = placemark else {
                return nil
            }
            
            return AddressSnapshot(
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
        
        return LocationSnapshot(
            coordinate: coordinate,
            altitude: self.altitude,
            horizontalAccuracy: self.horizontalAccuracy,
            verticalAccuracy: self.verticalAccuracy,
            address: address,
            timestamp: self.timestamp
        )
    }
}

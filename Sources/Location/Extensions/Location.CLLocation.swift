//
//  CLLocation.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation
#if !COCOAPODS
import RoverData
#endif

extension CLLocation {
    public func context(placemark: CLPlacemark?) -> Context.Location {
        let coordinate = Context.Location.Coordinate(
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude
        )
        
        let address: Context.Location.Address? = {
            guard let placemark = placemark else {
                return nil
            }
            
            return Context.Location.Address(
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
        
        return Context.Location(
            coordinate: coordinate,
            altitude: self.altitude,
            horizontalAccuracy: self.horizontalAccuracy,
            verticalAccuracy: self.verticalAccuracy,
            address: address,
            timestamp: self.timestamp
        )
    }
}

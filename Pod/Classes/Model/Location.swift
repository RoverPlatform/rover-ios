//
//  Location.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-16.
//
//

import Foundation
import CoreLocation

public class Location : NSObject {
    
    let coordinates: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let name: String
    let tags: [String]
    
    init(coordinates: CLLocationCoordinate2D, radius: CLLocationDistance, name: String, tags: [String]) {
        self.coordinates = coordinates
        self.radius = radius
        self.name = name
        self.tags = tags
    }
}
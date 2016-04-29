//
//  BeaconConfiguration.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-16.
//
//

import Foundation
import CoreLocation

public class BeaconConfiguration : NSObject {
    
    let UUID: NSUUID
    let majorNumber: CLBeaconMajorValue?
    let minorNumber: CLBeaconMinorValue?
    let tags: [String]
    let name: String
    
    init(name: String, UUID: NSUUID, majorNumber: CLBeaconMajorValue?, minorNumber: CLBeaconMinorValue?, tags: [String]) {
        self.name = name
        self.UUID = UUID
        self.majorNumber = majorNumber
        self.minorNumber = minorNumber
        self.tags = tags
    }
}

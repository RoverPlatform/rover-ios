//
//  BluetoothManager.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreBluetooth
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class BluetoothManager: NSObject {
    let centralManager: CBCentralManager
    let isEnabled = PersistedValue<Bool>(storageKey: "io.rover.RoverBluetooth.isEnabled")
        
    init(showPowerAlertKey: Bool) {
        let showPowerAlertValue: NSNumber = showPowerAlertKey ? 1 : 0
        let options: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: showPowerAlertValue]
        self.centralManager = CBCentralManager(delegate: nil, queue: nil, options: options)
        super.init()
        self.centralManager.delegate = self
    }
}

extension BluetoothManager: BluetoothContextProvider {
    var isBluetoothEnabled: Bool {
        return self.isEnabled.value ?? false
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.isEnabled.value = central.state == .poweredOn
    }
}

//
//  BluetoothManager.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreBluetooth

class BluetoothManager: NSObject {
    let centralManager = CBCentralManager()
    let isEnabled = PersistedValue<Bool>(storageKey: "io.rover.RoverBluetooth.isEnabled")
        
    override init() {
        super.init()
        self.centralManager.delegate = self
    }
}

extension BluetoothManager: BluetoothInfoProvider {
    var isBluetoothEnabled: Bool {
        get {
            return self.isEnabled.value ?? false
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.isEnabled.value = central.state == .poweredOn
    }
}

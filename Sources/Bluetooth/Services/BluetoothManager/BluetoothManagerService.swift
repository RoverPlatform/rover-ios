//
//  BluetoothManagerService.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreBluetooth

class BluetoothManagerService: NSObject, BluetoothManager {
    let central: CBCentralManager
    let eventQueue: EventQueue
    let logger: Logger
    let userDefaults: UserDefaults
    
    var isBluetoothEnabled: Bool?
    
    init(central: CBCentralManager, eventQueue: EventQueue, logger: Logger, userDefaults: UserDefaults) {
        self.central = central
        self.eventQueue = eventQueue
        self.logger = logger
        self.userDefaults = userDefaults
        super.init()
        central.delegate = self
    }
    
    func restore() {
        logger.debug("Restoring Bluetooth state...")
        
        if userDefaults.object(forKey: "io.rover.isBluetoothEnabled") == nil {
            logger.debug("Bluetooth state unknown")
            return
        }
        
        let isBluetoothEnabled = userDefaults.bool(forKey: "io.rover.isBluetoothEnabled")
        logger.debug("Bluetooth is currently \(isBluetoothEnabled ? "enabled" : "disabled")")
        self.isBluetoothEnabled = isBluetoothEnabled
    }
}

// MARK: CBCentralManagerDelegate

extension BluetoothManagerService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let isBluetoothEnabled = central.state == .poweredOn
        
        if self.isBluetoothEnabled == isBluetoothEnabled {
            return
        }
        
        let oldValue = self.isBluetoothEnabled
        self.isBluetoothEnabled = isBluetoothEnabled
        userDefaults.set(isBluetoothEnabled, forKey: "io.rover.isBluetoothEnabled")
        
        guard let wasBluetoothEnabled = oldValue else {
            return
        }
        
        if isBluetoothEnabled && !wasBluetoothEnabled {
            let event = EventInfo(name: "Bluetooth Enabled", namespace: "rover")
            eventQueue.addEvent(event)
        } else if !isBluetoothEnabled && wasBluetoothEnabled {
            let event = EventInfo(name: "Bluetooth Disabled", namespace: "rover")
            eventQueue.addEvent(event)
        }
    }
}

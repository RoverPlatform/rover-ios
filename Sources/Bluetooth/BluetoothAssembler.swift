//
//  BluetoothAssembler.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreBluetooth

public class BluetoothAssembler: Assembler {
    let showPowerAlertKey: Bool
    
    public init(showPowerAlertKey: Bool = false) {
        self.showPowerAlertKey = showPowerAlertKey
    }
    
    public func assemble(container: Container) {
        container.register(BluetoothInfoProvider.self) { _ in
            return BluetoothManager(showPowerAlertKey: self.showPowerAlertKey)
        }
    }
}

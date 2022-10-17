//
//  BluetoothAssembler.swift
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

public class BluetoothAssembler: Assembler {
    let showPowerAlertKey: Bool
    
    public init(showPowerAlertKey: Bool = false) {
        self.showPowerAlertKey = showPowerAlertKey
    }
    
    public func assemble(container: Container) {
        container.register(BluetoothContextProvider.self) { _ in
            BluetoothManager(showPowerAlertKey: self.showPowerAlertKey)
        }
    }
}

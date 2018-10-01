//
//  BluetoothAssembler.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreBluetooth

public class BluetoothAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        container.register(BluetoothContextProvider.self) { resolver in
            return BluetoothManager()
        }
    }
}

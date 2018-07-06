//
//  BluetoothContextProvider.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

struct BluetoothContextProvider: ContextProvider {
    let bluetoothManager: BluetoothManager
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.isBluetoothEnabled = bluetoothManager.isBluetoothEnabled
        return nextContext
    }
}

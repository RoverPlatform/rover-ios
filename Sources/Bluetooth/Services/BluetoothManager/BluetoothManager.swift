//
//  BluetoothManager.swift
//  RoverBluetooth
//
//  Created by Sean Rucker on 2018-03-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol BluetoothManager {
    var isBluetoothEnabled: Bool? { get }
    
    func restore()
}

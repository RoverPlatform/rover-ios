//
//  BluetoothStatusOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-10.
//
//

import CoreBluetooth

class BluetoothStatusOperation: ConcurrentOperation, CBCentralManagerDelegate {
    
    private var centralManager: CBCentralManager?
    private var completion: (Bool) -> Void
    //private static var foundStatus: CBCentralManagerState?
    
    required init(completion: (isOn: Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    override func execute() {
//        if let status = BluetoothStatusOperation.foundStatus {
//            completion(status == .PoweredOn)
//            finish()
//            return
//        }

        if cancelled {
            finish()
            return
        }
        
        rvLog("Checking Bluetooth status", level: .Trace)
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if cancelled {
            finish()
            return
        }
        
        //BluetoothStatusOperation.foundStatus = central.state
        rvLog("Determined Bluetooth status", data: central.state == .PoweredOn, level: .Trace)
        self.completion(central.state == .PoweredOn)
        finish()
    }
}
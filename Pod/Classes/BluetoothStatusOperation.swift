//
//  BluetoothStatusOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-10.
//
//

import CoreBluetooth

class BluetoothStatusOperation: ConcurrentOperation, CBCentralManagerDelegate {
    
    fileprivate var centralManager: CBCentralManager?
    fileprivate var completion: (Bool) -> Void
    //private static var foundStatus: CBCentralManagerState?
    
    required init(completion: @escaping (_ isOn: Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    override func execute() {
//        if let status = BluetoothStatusOperation.foundStatus {
//            completion(status == .PoweredOn)
//            finish()
//            return
//        }

        if isCancelled {
            finish()
            return
        }
        
        rvLog("Checking Bluetooth status", level: .trace)
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if isCancelled {
            finish()
            return
        }
        
        //BluetoothStatusOperation.foundStatus = central.state
        rvLog("Determined Bluetooth status", data: central.state == .poweredOn, level: .trace)
        self.completion(central.state == .poweredOn)
        finish()
    }
}

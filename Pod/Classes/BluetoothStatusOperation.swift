//
//  BluetoothStatusOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-10.
//
//

import CoreBluetooth

class BluetoothStatusOperation: NSOperation, CBCentralManagerDelegate {
    private var _finished = false
    private var _executing = false
    override private(set) var finished: Bool {
        get {
            return _finished
        }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    override private(set) var executing: Bool {
        get {
            return _executing
        }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    override var concurrent: Bool {
        return true
    }
    
    private var centralManager: CBCentralManager?
    private var completion: (Bool) -> Void
    private static var foundStatus: CBCentralManagerState?
    
    required init(completion: (isOn: Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    
    override func start() {
        guard !cancelled else {
            finished = true
            return
        }
        
        if let status = BluetoothStatusOperation.foundStatus {
            completion(status == .PoweredOn)
            finished = true
            return
        }
        
        executing = true
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        BluetoothStatusOperation.foundStatus = central.state
        self.completion(central.state == .PoweredOn)
        executing = false
        finished = true
    }
}
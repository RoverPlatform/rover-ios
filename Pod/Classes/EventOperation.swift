//
//  EventOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-15.
//
//
//                                         +--------+
//                                         | Region |
//                                   +--<--|  Map   |--<--+
//                                   |     +--------+     |
//                                   |                    |
// 	+--------+   +-----------+   +------+   +-------+     +--------+
// 	|  BLE   |-<-|   Event   |-<-| HTTP |-<-| Event |--<--| Finish |
// 	| Status |   | Serialize |   |      |   |  Map  |     |        |
// 	+--------+   +-----------+   +------+   +-------+     +--------+
//
//

import UIKit
import CoreLocation

protocol EventOperationDelegate: class {
    func eventOperation(_ operation: EventOperation, didPostEvent event: Event)
    func eventOperation(_ operation: EventOperation, didReceiveRegions regions: [CLRegion])
}

class EventOperation: ConcurrentOperation {

    fileprivate let internalQueue = OperationQueue()
    
    fileprivate var event: Event
    
    weak var delegate: EventOperationDelegate?
    
    required init(event: Event) {
        self.event = event
        
        super.init()
        
        internalQueue.isSuspended = true
        
        // Operations
        
        let finishingOperation = BlockOperation {
            self.finish()
        }
        let regionMappingOperation = MappingOperation { (regions: [CLRegion]) in
            guard regions.count > 0 else { return }
            
            //rvLog("Received new regions", data: regions, level: .Trace)
            
            DispatchQueue.main.async {
                self.delegate?.eventOperation(self, didReceiveRegions: regions)
            }
        }
        let eventMappingOperation = MappingOperation { (event: Event) in
            // TODO: dispatch_async?
            //rvLog("Event submitted: \(event)", data: event, level: .Trace)
            self.delegate?.eventOperation(self, didPostEvent: event)
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.events.urlRequest) {
            [unowned regionMappingOperation, unowned eventMappingOperation]
            JSON, error in

            if let included = JSON?["included"] as? [[String: AnyObject]] {
                regionMappingOperation.json = ["data": included]
            }
            eventMappingOperation.json = JSON
        }
        let serializingOperation = SerializingOperation(model: event) { [unowned networkOperation] JSON in
            networkOperation.payload = JSON
        }
        let bluetoothStatusOperation = BluetoothStatusOperation { isOn in
            Device.bluetoothOn = isOn
        }
        
        eventMappingOperation.included = event.properties
        
        finishingOperation.addDependency(eventMappingOperation)
        finishingOperation.addDependency(regionMappingOperation)
        
        eventMappingOperation.addDependency(networkOperation)
        regionMappingOperation.addDependency(networkOperation)
        networkOperation.addDependency(serializingOperation)
        serializingOperation.addDependency(bluetoothStatusOperation)
        
        internalQueue.addOperation(bluetoothStatusOperation)
        internalQueue.addOperation(serializingOperation)
        internalQueue.addOperation(networkOperation)
        internalQueue.addOperation(eventMappingOperation)
        internalQueue.addOperation(regionMappingOperation)
        
        internalQueue.addOperation(finishingOperation)
    }
    
    override func cancel() {
        internalQueue.cancelAllOperations()
        
        super.cancel()
        
        finish()
    }
    
    override func execute() {
        rvLog("Submitting event", data: self.event, level: .trace)
        
        internalQueue.isSuspended = false
    }
    
}

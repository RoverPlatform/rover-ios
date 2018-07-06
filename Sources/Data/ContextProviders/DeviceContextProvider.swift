//
//  DeviceContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-08-14.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class DeviceContextProvider: ContextProvider {
    let device: UIDevice
    let logger: Logger
    
    lazy var operatingSystemName: String = {
        return device.systemName
    }()
    
    lazy var operatingSystemVersion: String = {
        return device.systemVersion
    }()
    
    lazy var deviceIdentifier: String? = {
        return device.identifierForVendor?.uuidString
    }()
    
    lazy var deviceManufacturer: String = {
        return "Apple"
    }()
    
    lazy var deviceModel: String? = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = MemoryLayout<CChar>.size
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: size) {
                String(cString: UnsafePointer<CChar>($0))
            }
        }
        guard let deviceModel = String(validatingUTF8: modelCode) else {
            logger.warn("Failed to capture device model")
            return nil
        }
        
        return deviceModel
    }()
    
    lazy var deviceName: String = {
        return device.name
    }()
    
    init(device: UIDevice, logger: Logger) {
        self.device = device
        self.logger = logger
    }

    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.operatingSystemName = operatingSystemName
        nextContext.operatingSystemVersion = operatingSystemVersion
        nextContext.deviceIdentifier = deviceIdentifier
        nextContext.deviceManufacturer = deviceManufacturer
        nextContext.deviceModel = deviceModel
        nextContext.deviceName = deviceName
        return nextContext
    }
}

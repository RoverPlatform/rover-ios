// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import CoreBluetooth
import RoverFoundation
import RoverData

class BluetoothManager: NSObject {
    let centralManager: CBCentralManager
    let isEnabled = PersistedValue<Bool>(storageKey: "io.rover.RoverBluetooth.isEnabled")
        
    init(showPowerAlertKey: Bool) {
        let showPowerAlertValue: NSNumber = showPowerAlertKey ? 1 : 0
        let options: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: showPowerAlertValue]
        self.centralManager = CBCentralManager(delegate: nil, queue: nil, options: options)
        super.init()
        self.centralManager.delegate = self
    }
}

extension BluetoothManager: BluetoothContextProvider {
    var isBluetoothEnabled: Bool {
        return self.isEnabled.value ?? false
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.isEnabled.value = central.state == .poweredOn
    }
}

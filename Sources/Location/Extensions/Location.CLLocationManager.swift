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

import CoreLocation

extension CLLocationManager {
    public func monitor(for regionsToMonitor: Set<CLRegion>) {
        // Remove regions that should no longer be monitored
        for regionToRemove in monitoredRegions.subtracting(regionsToMonitor) {
            self.stopMonitoring(for: regionToRemove)
            
            if let beaconRegion = regionToRemove as? CLBeaconRegion {
                self.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
            }
        }
        
        // Add regions that are not already being monitored
        for regionToAdd in regionsToMonitor.subtracting(monitoredRegions) {
            self.startMonitoring(for: regionToAdd)
            
            if let beaconRegion = regionToAdd as? CLBeaconRegion {
                self.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
            }
        }
    }
}

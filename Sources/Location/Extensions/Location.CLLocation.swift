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
import RoverData

extension CLLocation {
    public func context(placemark: CLPlacemark?) -> Context.Location {
        let coordinate = Context.Location.Coordinate(
            latitude: self.coordinate.latitude.roundToDecimal(2),
            longitude: self.coordinate.longitude.roundToDecimal(2)
        )
        
        let address: Context.Location.Address? = {
            guard let placemark = placemark else {
                return nil
            }
            
            return Context.Location.Address(
                city: placemark.locality,
                state: placemark.administrativeArea,
                country: placemark.country,
                isoCountryCode: placemark.isoCountryCode,
                subAdministrativeArea: placemark.administrativeArea
            )
        }()
        
        return Context.Location(
            coordinate: coordinate,
            altitude: self.altitude,
            horizontalAccuracy: self.horizontalAccuracy,
            verticalAccuracy: self.verticalAccuracy,
            address: address,
            timestamp: self.timestamp
        )
    }
}

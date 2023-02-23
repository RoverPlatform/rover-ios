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

extension CLLocationCoordinate2D {
    func distanceTo(_ other: CLLocationCoordinate2D) -> CLLocationDistance {
        let lat1 = degreesToRadians(self.latitude)
        let lon1 = degreesToRadians(self.longitude)
        let lat2 = degreesToRadians(other.latitude)
        let lon2 = degreesToRadians(other.longitude)
        return earthRadius * ahaversin(haversin(lat2 - lat1) + cos(lat1) * cos(lat2) * haversin(lon2 - lon1))
    }
}

// https://en.wikipedia.org/wiki/Figure_of_the_Earth
let earthRadius: Double = 6_371_000

private let haversin: (Double) -> Double = {
    (1 - cos($0)) / 2
}

private let ahaversin: (Double) -> Double = {
    2 * asin(sqrt($0))
}

private let degreesToRadians: (Double) -> Double = {
    ($0 / 360) * 2 * Double.pi
}

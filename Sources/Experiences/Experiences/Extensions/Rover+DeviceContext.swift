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

import RoverFoundation
import RoverData
import Foundation

internal extension Rover {
    var deviceContext: [String: Any] {
        get {
            resolve(ContextProvider.self)!.context.allProperties
        }
    }
}

// This is uses reflection to determine the names of properties of the object,
// then uses them as keys for a dictionary that contains the values of those properties.
// This is taken from:
// https://stackoverflow.com/questions/27292255/how-to-loop-over-struct-properties-in-swift

extension Context: Loopable {}
extension Context.Location: Loopable {}
extension Context.Location.Address: Loopable {}

// NB. this format differs from what we sent as JSON in the event queue
// there, coordinate is encoded as an array/tuple [lat, long]. Here,
// for better ergonomics for using the coordinates in an
// experiences, it is encoded here as an object instead.
extension Context.Location.Coordinate: Loopable {}

internal protocol Loopable {
    var allProperties: [String: Any] { get }
}

internal extension Loopable {
    var allProperties: [String: Any] {
        var result = [String: Any]()
        Mirror(reflecting: self).children.forEach { child in
            if let property = child.label {
                if let loopable = child.value as? Loopable {
                    result[property] = loopable.allProperties
                } else {
                    result[property] = child.value
                }
            }
        }
        return result
    }
}

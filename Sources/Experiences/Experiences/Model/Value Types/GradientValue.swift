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

import CoreGraphics
import SwiftUI

public struct GradientValue {
    public struct Stop: Decodable {
        public var color: ColorValue
        public var position: Double
    }
    
    /// In a parametric coordinate space, between 0 and 1.
    public var from: CGPoint
    
    /// In a parametric coordinate space, between 0 and 1.
    public var to: CGPoint
    
    public var stops: [Stop]
    
    public static var clear: GradientValue {
        GradientValue(
            from: CGPoint(x: 0.5, y: 0),
            to: CGPoint(x: 0.5, y: 1),
            stops: [
                Stop(color: .clear, position: 0),
                Stop(color: .clear, position: 1)
            ]
        )
    }
}

extension GradientValue: Decodable {
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case stops
    }
        
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decodeIfPresent(CGPoint.self, forKey: .from) ?? .zero
        to = try container.decodeIfPresent(CGPoint.self, forKey: .to) ?? .zero
        stops = try container.decodeIfPresent([Stop].self, forKey: .stops) ?? []
    }
}

// MARK: SwiftUI Value

extension GradientValue {
    public func swiftUIGradient(startPoint: UnitPoint? = nil, endPoint: UnitPoint? = nil) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(
                stops: stops
                    .sorted { $0.position < $1.position }
                    .map { Gradient.Stop(color: $0.color.color, location: CGFloat($0.position)) }
            ),
            startPoint: startPoint ?? .init(x: from.x, y: from.y),
            endPoint: endPoint ?? .init(x: to.x, y: to.y)
        )
    }
}

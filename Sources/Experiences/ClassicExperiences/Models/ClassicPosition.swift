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

public struct ClassicPosition: Decodable {
    public enum HorizontalAlignment {
        case center(offset: Double, width: Double)
        case left(offset: Double, width: Double)
        case right(offset: Double, width: Double)
        case fill(leftOffset: Double, rightOffset: Double)
    }
    
    public enum VerticalAlignment {
        case bottom(offset: Double, height: ClassicHeight)
        case middle(offset: Double, height: ClassicHeight)
        case fill(topOffset: Double, bottomOffset: Double)
        case stacked(topOffset: Double, bottomOffset: Double, height: ClassicHeight)
        case top(offset: Double, height: ClassicHeight)
    }
    
    public var horizontalAlignment: HorizontalAlignment
    public var verticalAlignment: VerticalAlignment
}

// MARK: Position.HorizontalAlignment

extension ClassicPosition.HorizontalAlignment: Decodable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case offset
        case width
        case leftOffset
        case rightOffset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "HorizontalAlignmentCenter":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .center(offset: offset, width: width)
        case "HorizontalAlignmentLeft":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .left(offset: offset, width: width)
        case "HorizontalAlignmentRight":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .right(offset: offset, width: width)
        case "HorizontalAlignmentFill":
            let leftOffset = try container.decode(Double.self, forKey: .leftOffset)
            let rightOffset = try container.decode(Double.self, forKey: .rightOffset)
            self = .fill(leftOffset: leftOffset, rightOffset: rightOffset)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected on of HorizontalAlignmentCenter, HorizontalAlignmentLeft, HorizontalAlignmentRight or HorizontalAlignmentFill - found \(typeName)")
        }
    }
}

// MARK: Position.VerticalAlignment

extension ClassicPosition.VerticalAlignment: Decodable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case offset
        case height
        case topOffset
        case bottomOffset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "VerticalAlignmentBottom":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(ClassicHeight.self, forKey: .height)
            self = .bottom(offset: offset, height: height)
        case "VerticalAlignmentMiddle":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(ClassicHeight.self, forKey: .height)
            self = .middle(offset: offset, height: height)
        case "VerticalAlignmentFill":
            let topOffset = try container.decode(Double.self, forKey: .topOffset)
            let bottomOffset = try container.decode(Double.self, forKey: .bottomOffset)
            self = .fill(topOffset: topOffset, bottomOffset: bottomOffset)
        case "VerticalAlignmentStacked":
            let topOffset = try container.decode(Double.self, forKey: .topOffset)
            let bottomOffset = try container.decode(Double.self, forKey: .bottomOffset)
            let height = try container.decode(ClassicHeight.self, forKey: .height)
            self = .stacked(topOffset: topOffset, bottomOffset: bottomOffset, height: height)
        case "VerticalAlignmentTop":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(ClassicHeight.self, forKey: .height)
            self = .top(offset: offset, height: height)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected on of VerticalAlignmentBottom, VerticalAlignmentMiddle, VerticalAlignmentFill, VerticalAlignmentStacked or VerticalAlignmentTop - found \(typeName)")
        }
    }
}

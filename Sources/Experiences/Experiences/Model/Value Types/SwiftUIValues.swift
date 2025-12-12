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

import SwiftUI
import os.log

// MARK: Axis

struct AxisValue: Decodable {
    let axis: Axis
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value {
        case "horizontal":
            axis = .horizontal
        case "vertical":
            axis = .vertical
        default:
            axis = .vertical
            rover_log(.error, "Unsupported axis: %@", value)
        }
    }
}

// MARK: TextAlignment

struct TextAlignmentValue: Decodable {
    let textAlignment: TextAlignment
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value {
        case "center":
            textAlignment = .center
        case "leading":
            textAlignment = .leading
        case "trailing":
            textAlignment = .trailing
        default:
            textAlignment = .center
            rover_log(.error, "Unsupported text alignment: %@", value)
        }
    }
}

// MARK: HorizontalAlignment

struct HorizontalAlignmentValue: Decodable {
    let horizontalAlignment: HorizontalAlignment
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "center":
            horizontalAlignment = .center
        case "leading":
            horizontalAlignment = .leading
        case "trailing":
            horizontalAlignment = .trailing
        default:
            rover_log(.error, "Unsupported horizontal alignment: %@", rawValue)
            horizontalAlignment = .center
        }
    }
}

// MARK: VerticalAlignment

struct VerticalAlignmentValue: Decodable {
    let verticalAlignment: VerticalAlignment
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "bottom":
            verticalAlignment = .bottom
        case "center":
            verticalAlignment = .center
        case "baseline":
            verticalAlignment = .firstTextBaseline
        case "top":
            verticalAlignment = .top
        default:
            rover_log(.error, "Unsupported vertical alignment: %@", rawValue)
            verticalAlignment = .bottom
        }
    }
}

// MARK: Alignment

struct AlignmentValue: Decodable {
    let alignment: Alignment
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "bottom":
            alignment = .bottom
        case "bottomLeading":
            alignment = .bottomLeading
        case "bottomTrailing":
            alignment = .bottomTrailing
        case "center":
            alignment = .center
        case "leading":
            alignment = .leading
        case "top":
            alignment = .top
        case "topLeading":
            alignment = .topLeading
        case "topTrailing":
            alignment = .topTrailing
        case "trailing":
            alignment = .trailing
        default:
            rover_log(.error, "Unsupported alignment: %@", rawValue)
            alignment = .center
        }
    }
}

// MARK: Edge

struct EdgeValue: Decodable, Identifiable, Hashable {
    let edge: Edge
    
    var id: Int8 {
        edge.rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "top":
            edge = .top
        case "leading":
            edge = .leading
        case "bottom":
            edge = .bottom
        case "trailing":
            edge = .trailing
        default:
            edge = .leading
            rover_log(.error, "Unsupported edge: %@", rawValue)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(edge.rawValue)
    }
}

// MARK: SwiftUI.Font.TextStyle

struct TextStyleValue: Decodable {
    let textStyle: SwiftUI.Font.TextStyle
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "largeTitle":
            textStyle = .largeTitle
        case "title":
            textStyle = .title
        case "title2":
            textStyle = .title2
        case "title3":
            textStyle = .title3
        case "headline":
            textStyle = .headline
        case "body":
            textStyle = .body
        case "callout":
            textStyle = .callout
        case "subheadline":
            textStyle = .subheadline
        case "footnote":
            textStyle = .footnote
        case "caption":
            textStyle = .caption
        case "caption2":
            textStyle = .caption2
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid value: \(value.self)"
            )
        }
    }
}

// MARK: SwiftUI.Font.Weight

struct WeightValue: Decodable {
    var weight: SwiftUI.Font.Weight
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "ultraLight":
            weight = .ultraLight
        case "thin":
            weight = .thin
        case "light":
            weight = .light
        case "regular":
            weight = .regular
        case "medium":
            weight = .medium
        case "semibold":
            weight = .semibold
        case "bold":
            weight = .bold
        case "heavy":
            weight = .heavy
        case "black":
            weight = .black
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid value: \(value.self)"
            )
        }
    }
}

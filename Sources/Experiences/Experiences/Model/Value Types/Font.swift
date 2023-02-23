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

import Foundation
import CoreGraphics
import SwiftUI

public typealias FontFamily = String

public typealias FontName = String

public enum Font: Decodable, Hashable {

    public enum Emphasis: String, Hashable, Decodable {
        case bold
        case italic
    }

    /// A system font with a given semantic style that responds to the Dynamic Type system on iOS and the equivalent on Android.
    case dynamic(textStyle: SwiftUI.Font.TextStyle, emphases: Set<Font.Emphasis>)

    /// A system font with a fixed size and weight.
    case fixed(size: CGFloat, weight: SwiftUI.Font.Weight)
    
    /// A font which uses the `CustomFont` value from a `DocumentFont` matching the `fontFamily` and `textStyle`.
    case document(fontFamily: FontFamily, textStyle: SwiftUI.Font.TextStyle)

    /// A custom font which uses the supplied `FontName` and given `size`.
    case custom(fontName: FontName, size: CGFloat)

    public static let largeTitle = Font.dynamic(textStyle: .largeTitle, emphases: [])
    public static let title = Font.dynamic(textStyle: .title, emphases: [])
    @available(iOS 14.0, *)
    public static let title2 = Font.dynamic(textStyle: .title2, emphases: [])
    @available(iOS 14.0, *)
    public static let title3 = Font.dynamic(textStyle: .title3, emphases: [])
    public static let headline = Font.dynamic(textStyle: .headline, emphases: [])
    public static let body = Font.dynamic(textStyle: .body, emphases: [])
    public static let callout = Font.dynamic(textStyle: .callout, emphases: [])
    public static let subheadline = Font.dynamic(textStyle: .subheadline, emphases: [])
    public static let footnote = Font.dynamic(textStyle: .footnote, emphases: [])
    public static let caption = Font.dynamic(textStyle: .caption, emphases: [])
    @available(iOS 14.0, *)
    public static let caption2 = Font.dynamic(textStyle: .caption2, emphases: [])

    private enum CodingKeys: String, CodingKey {
        case caseName = "__caseName"
        case textStyle
        case emphases
        case size
        case weight
        case fontFamily
        case fontName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseName = try container.decode(String.self, forKey: .caseName)
        switch caseName {
        case "dynamic":
            let textStyle = try container.decode(TextStyleValue.self, forKey: .textStyle).textStyle
            let emphases = try container.decode(Set<Font.Emphasis>.self, forKey: .emphases)
            self = .dynamic(textStyle: textStyle, emphases: emphases)
        case "fixed":
            let size = try container.decode(CGFloat.self, forKey: .size)
            let weight = try container.decode(WeightValue.self, forKey: .weight).weight
            self = .fixed(size: size, weight: weight)
        case "document":
            let fontFamily = try container.decode(FontFamily.self, forKey: .fontFamily)
            let textStyle = try container.decode(TextStyleValue.self, forKey: .textStyle).textStyle
            self = .document(fontFamily: fontFamily, textStyle: textStyle)
        case "custom":
            let fontName = try container.decode(FontName.self, forKey: .fontName)
            let size = try container.decode(CGFloat.self, forKey: .size)
            self = .custom(fontName: fontName, size: size)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .caseName,
                in: container,
                debugDescription: "Invalid value: \(caseName)"
            )
        }
    }
}

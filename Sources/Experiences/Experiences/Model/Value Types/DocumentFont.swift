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

public struct DocumentFont: Decodable {
    public struct CustomFont: Decodable {
        var fontName: FontName
        var size: CGFloat
    }
    
    public struct FontSource: Decodable {
        var assetName: String
        var fontNames: [String]
        var assetUrl: URL
        
        public enum CodingKeys: CodingKey {
            case assetName
            case fontNames
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.assetName = try container.decode(String.self, forKey: DocumentFont.FontSource.CodingKeys.assetName)
            self.fontNames = try container.decode([String].self, forKey: DocumentFont.FontSource.CodingKeys.fontNames)
            
            let assetContext = decoder.userInfo[.assetContext] as! AssetContext
            self.assetUrl = assetContext.assetUrl(for: .font, name: self.assetName)
        }
    }
    
    public var fontFamily: FontFamily
    public var largeTitle: CustomFont
    public var title: CustomFont
    public var title2: CustomFont
    public var title3: CustomFont
    public var headline: CustomFont
    public var body: CustomFont
    public var callout: CustomFont
    public var subheadline: CustomFont
    public var footnote: CustomFont
    public var caption: CustomFont
    public var caption2: CustomFont
    public var sources: [FontSource]
}


public extension DocumentFont {
    var urls: [URL] {
        self.sources.map { $0.assetUrl }
    }
}

extension DocumentFont {
    func fontForStyle(_ textStyle: SwiftUI.Font.TextStyle) -> CustomFont {
        switch textStyle {
        case .largeTitle:
            return self.largeTitle
        case .title:
            return self.title
        case.title2:
            return self.title2
        case .title3:
            return self.title3
        case .headline:
            return self.headline
        case .body:
            return self.body
        case .callout:
            return self.callout
        case .subheadline:
            return self.subheadline
        case .footnote:
            return self.footnote
        case .caption:
            return self.caption
        case .caption2:
            return self.caption2
        default:
            return self.body
        }
    }
}

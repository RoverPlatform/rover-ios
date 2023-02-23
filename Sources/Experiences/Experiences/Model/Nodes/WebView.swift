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

final class WebView: Layer {
    public enum Source: Decodable, Hashable {
        case url(String)
        case html(String)
        
        private enum CodingKeys: String, CodingKey {
            case caseName = "__caseName"
            case value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let caseName = try container.decode(String.self, forKey: .caseName)
            let value = try container.decode(String.self, forKey: .value)
            switch caseName {
            case "url":
                self = .url(value)
            case "html":
                self = .html(value)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .caseName,
                    in: container,
                    debugDescription: "Invalid value: \(caseName)"
                )
            }
        }
    }
    
    public let source: Source
    public let isScrollEnabled: Bool
    
    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, source: Source, isScrollEnabled: Bool) {
        self.source = source
        self.isScrollEnabled = isScrollEnabled
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }

    // MARK: Decodable

    private enum CodingKeys: String, CodingKey {
        case source
        case isScrollEnabled
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        source = try container.decode(Source.self, forKey: .source)
        isScrollEnabled = try container.decode(Bool.self, forKey: .isScrollEnabled)
        try super.init(from: decoder)
    }
}

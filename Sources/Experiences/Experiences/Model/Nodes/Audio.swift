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
import SwiftUI

class Audio: Layer {
    public struct Source: Decodable {
        /// A streamable media source available through the network.
        let url: String

        private enum CodingKeys: String, CodingKey {
            case caseName = "__caseName"
            case assetName
            case url
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let assetContext = decoder.userInfo[.assetContext] as! AssetContext

            let caseName = try container.decode(String.self, forKey: .caseName)
            switch caseName {
            case "fromFile":
                let fileName = try container.decode(String.self, forKey: .assetName)
                self.url = assetContext.assetUrl(for: .media, name: fileName).absoluteString
            case "fromURL":
                self.url = try container.decode(String.self, forKey: .url)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .caseName,
                    in: container,
                    debugDescription: "Invalid value: \(caseName)"
                )
            }
        }
    }

    /// Audio URL
    public let sourceURL: String

    /// When true the audio will begin playing when the Screen is displayed.
    public let autoPlay: Bool

    /// When true the video will loop.
    public let looping: Bool

    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil,  sourceURL: String, autoPlay: Bool, looping: Bool) {
        self.sourceURL = sourceURL
        self.autoPlay = autoPlay
        self.looping = looping
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }

    // MARK: Codable
    
    private enum CodingKeys: String, CodingKey {
        case source
        case autoPlay
        case looping
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decode(Source.self, forKey: .source)
        
        self.sourceURL = source.url
        self.autoPlay = try container.decode(Bool.self, forKey: .autoPlay)
        self.looping = try container.decode(Bool.self, forKey: .looping)
        try super.init(from: decoder)
    }
}

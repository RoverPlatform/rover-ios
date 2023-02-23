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

final class PageControl: Layer {
    /// The carousel node this Page Control is associated with.
    var carousel: Carousel?
    /// The style of indicator bullets.
    let style: PageControl.Style
    /// If true, and the associated Carousel lacks more than one page,
    /// hides the page control.
    let hidesForSinglePage: Bool
    
    init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, carousel: Carousel? = nil, style: PageControl.Style, hidesForSinglePage: Bool) {
        self.carousel = carousel
        self.style = style
        self.hidesForSinglePage = hidesForSinglePage
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }
        
    // MARK: Decodable
    
    private enum CodingKeys: String, CodingKey {
        case style
        case hidesForSinglePage
        case carouselID
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decode(PageControl.Style.self, forKey: .style)
        hidesForSinglePage = try container.decode(Bool.self, forKey: .hidesForSinglePage)

        try super.init(from: decoder)

        if container.contains(.carouselID) {
            let coordinator = decoder.userInfo[.decodingCoordinator] as! DecodingCoordinator
            let carouselID = try container.decode(Node.ID.self, forKey: .carouselID)
            coordinator.registerOneToOneRelationship(nodeID: carouselID, to: self, keyPath: \.carousel)
        }
    }
}

extension PageControl {
    enum Style: Decodable {
        case `default`
        case light
        case dark
        case inverted
        case custom(normalColor: ColorReference, currentColor: ColorReference)
        case image(normalImage: Image, normalColor: ColorReference, currentImage: Image, currentColor: ColorReference)

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case caseName = "__caseName"
            case normalColor
            case currentColor
            case normalImage
            case currentImage
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeName = try container.decode(String.self, forKey: .caseName)
            switch typeName {
            case "default":
                self = .default
            case "light":
                self = .light
            case "dark":
                self = .dark
            case "inverted":
                self = .inverted
            case "custom":
                let normalColor = try container.decode(ColorReference.self, forKey: .normalColor)
                let currentColor = try container.decode(ColorReference.self, forKey: .currentColor)
                self = .custom(normalColor: normalColor, currentColor: currentColor)
            case "image":
                let normalColor = try container.decode(ColorReference.self, forKey: .normalColor)
                let currentColor = try container.decode(ColorReference.self, forKey: .currentColor)
                let normalImage = try container.decode(Image.self, forKey: .normalImage)
                let currentImage = try container.decode(Image.self, forKey: .currentImage)
                self = .image(normalImage: normalImage, normalColor: normalColor, currentImage: currentImage, currentColor: currentColor)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .caseName,
                    in: container,
                    debugDescription: "Invalid value: \(typeName)"
                )
            }
        }
    }
}

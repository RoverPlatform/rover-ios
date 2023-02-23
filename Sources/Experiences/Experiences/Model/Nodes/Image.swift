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

final class Image: Layer {
    public enum ResizingMode: String, Codable {
        case originalSize
        case scaleToFit
        case scaleToFill
        case tile
        case stretch
    }
    
    struct Source: Decodable {
        /// A streamable media source available through the network.
        let url: String?
        let image: ImageValue?

        private enum CodingKeys: String, CodingKey {
            case caseName = "__caseName"
            case assetName
            case url
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let coordinator = decoder.userInfo[.decodingCoordinator] as! DecodingCoordinator
            let assetContext = decoder.userInfo[.assetContext] as! AssetContext

            let caseName = try container.decode(String.self, forKey: .caseName)
            switch caseName {
            case "fromFile":
                let fileName = try container.decode(String.self, forKey: .assetName)
                if let imageValue = coordinator.imageByFilename(fileName) {
                    self.image = imageValue
                    self.url = nil
                } else {
                    self.url = assetContext.assetUrl(for: .image, name: fileName).absoluteString
                    self.image = nil
                }
            case "fromURL":
                self.url = try container.decode(String.self, forKey: .url)
                self.image = nil
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .caseName,
                    in: container,
                    debugDescription: "Invalid value: \(caseName)"
                )
            }
        }
    }

    /// The URL for the image to use for light mode.
    /// If darkModeImageURL is omitted then use this URL during dark mode as well.
    public let imageURL: String?
    /// The URL for the image to use only when the device is in dark mode.
    public let darkModeImageURL: String?
    /// The screen resolution this image is design for. Typically 1.0, 2.0 or 3.0
    public let resolution: CGFloat
    /// Specifies image sizing behaviour.
    public let resizingMode: ResizingMode
    /// The blur hash for the image specified in imageURL.
    public let blurHash: String?
    /// The blur hash for the image specified in `darkModeImageURL`.
    /// This key is omitted if `darkModeImageURL` key is omitted.
    public let darkModeBlurHash: String?
    /// The width of the image provided by `imageURL`.
    public let imageWidth: Int?
    /// The height of the image provided by `imageURL`.
    public let imageHeight: Int?
    /// The width of the image provided by `darkModeImageURL`.
    public let darkModeImageWidth: Int?
    /// The height of the image provided by `darkModeImageURL`.
    public let darkModeImageHeight: Int?
    
    /// Developers may create an Image with their own, already in memory, UIImage.
    public let inlineImage: UIImage?
    
    public let darkModeInlineImage: UIImage?
    
    public let dimensions: CGSize?
    
    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, imageURL: String, darkModeImageURL: String?, resolution: CGFloat, resizingMode: Image.ResizingMode, blurHash: String?, darkModeBlurHash: String?, imageWidth: Int?, imageHeight: Int?, darkModeImageWidth: Int?, darkModeImageHeight: Int?, dimensions: CGSize?) {
        self.imageURL = imageURL
        self.darkModeImageURL = darkModeImageURL
        self.resolution = resolution
        self.resizingMode = resizingMode
        self.blurHash = blurHash
        self.darkModeBlurHash = darkModeBlurHash
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.darkModeImageWidth = darkModeImageWidth
        self.darkModeImageHeight = darkModeImageHeight
        self.inlineImage = nil
        self.darkModeInlineImage = nil
        self.dimensions = dimensions
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }
    
    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, image: UIImage, darkModeImage: UIImage?, resolution: CGFloat? = nil, resizingMode: Image.ResizingMode, blurHash: String?, darkModeBlurHash: String?, dimensions: CGSize?) {
        self.imageURL = nil
        self.darkModeImageURL = nil
        self.resizingMode = resizingMode
        self.blurHash = blurHash
        self.darkModeBlurHash = darkModeBlurHash
        self.resolution = resolution ?? image.scale
        self.imageWidth = Int(image.size.width * image.scale)
        self.imageHeight = Int(image.size.height * image.scale)
        self.darkModeImageWidth = darkModeImage.map { Int($0.size.width * $0.scale) }
        self.darkModeImageHeight = darkModeImage.map { Int($0.size.height * $0.scale) }
        self.inlineImage = image
        self.darkModeInlineImage = darkModeImage
        self.dimensions = dimensions
        
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }
    
    // MARK: Decodable
    
    private enum CodingKeys: String, CodingKey {
        case source
        case darkModeSource
        case imageName
        case resolution
        case resizingMode
        case blurHash
        case darkModeBlurHash
        case imageWidth
        case imageHeight
        case darkModeImageWidth
        case darkModeImageHeight
        case dimensions
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decode(Source.self, forKey: .source)
        imageURL = source.url
        inlineImage = source.image?.uiImage
        let darkModeSource = try container.decodeIfPresent(Source.self, forKey: .darkModeSource)
        darkModeImageURL = darkModeSource?.url
        darkModeInlineImage = darkModeSource?.image?.uiImage
        resolution = try container.decode(CGFloat.self, forKey: .resolution)
        resizingMode = try container.decode(ResizingMode.self, forKey: .resizingMode)
        blurHash = try container.decodeIfPresent(String.self, forKey: .blurHash)
        darkModeBlurHash = try container.decodeIfPresent(String.self, forKey: .darkModeBlurHash)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        darkModeImageWidth = try container.decodeIfPresent(Int.self, forKey: .darkModeImageWidth)
        darkModeImageHeight = try container.decodeIfPresent(Int.self, forKey: .darkModeImageHeight)
        dimensions = try container.decodeIfPresent(CGSize.self, forKey: .dimensions)
        try super.init(from: decoder)
    }
}

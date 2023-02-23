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

class Video: Layer {

    public enum ResizingMode: String, Decodable {
        case scaleToFit
        case scaleToFill
    }
    
    struct Source: Decodable, Hashable {
        /// A streamable media source available through the network.
        let url: String

        private enum CodingKeys: String, CodingKey {
            case caseName = "__caseName"
            case assetName
            case url
        }

        init(from decoder: Decoder) throws {
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

    /// Video URL
    public let sourceURL: String

    /// Poster image URL
    public let posterImageURL: String?

    /// Resizing mode
    public let resizingMode: ResizingMode

    /// When true the media player shown in the Rover layer will feature playback/transport controls.
    public let showControls: Bool

    /// When true the video will begin playing when the Screen is displayed.
    public let autoPlay: Bool

    /// When true the video will loop.
    public let looping: Bool

    /// When true audio track is inhibited from playback.
    public let removeAudio: Bool

    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, sourceURL: String, posterImageURL: String?, resizingMode: ResizingMode, showControls: Bool, autoPlay: Bool, looping: Bool, removeAudio: Bool) {
        self.sourceURL = sourceURL
        self.posterImageURL = posterImageURL
        self.resizingMode = resizingMode
        self.showControls = showControls
        self.autoPlay = autoPlay
        self.looping = looping
        self.removeAudio = removeAudio
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case posterImageName
        case resizingMode
        case showControls
        case autoPlay
        case looping
        case removeAudio
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordinator = decoder.userInfo[.decodingCoordinator] as! DecodingCoordinator

        let source = try container.decode(Source.self, forKey: .source)
        if let posterImageName = try container.decodeIfPresent(String.self, forKey: .posterImageName) {
            let fm = FileManager()
            let fileURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(posterImageName, isDirectory: false)
            try? fm.removeItem(at: fileURL)

            try coordinator.imageByFilename(posterImageName)?.data.write(to: fileURL)
            self.posterImageURL = fileURL.absoluteString
        } else {
            self.posterImageURL = nil
        }
        self.sourceURL = source.url
        self.resizingMode = try container.decode(RoverExperiences.Video.ResizingMode.self, forKey: .resizingMode)
        self.showControls = try container.decode(Bool.self, forKey: .showControls)
        self.autoPlay = try container.decode(Bool.self, forKey: .autoPlay)
        self.looping = try container.decode(Bool.self, forKey: .looping)
        self.removeAudio = try container.decode(Bool.self, forKey: .removeAudio)
        try super.init(from: decoder)
    }
}

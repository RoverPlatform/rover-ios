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

struct ImageView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.data) private var data
    
    var image: RoverExperiences.Image
    
    var body: some View {
        if let inlineImage = inlineImage {
            imageView(uiImage: inlineImage)
        } else if let urlString = urlString?.evaluatingExpressions(data: data, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext), let resolvedURL = URL(string: urlString) {
            imageFetcher(url: resolvedURL)
        }
    }
    
    private func imageFetcher(url: URL) -> some View {
        ImageFetcher(url: url) { uiImage in
            imageView(uiImage: uiImage)
                .transition(.opacity)
        } placeholder: {
            PlaceholderView(
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
            .transition(.opacity)
        }
    }
    
#if compiler(>=5.9)
    @ViewBuilder
    private func imageView(uiImage: UIImage) -> some View {
        if #available(iOS 17, *) {
            AccessibleAnimatedImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
        } else if uiImage.isAnimated {
            AnimatedImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
        } else {
            StaticImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
        }
    }
#else
    @ViewBuilder
    private func imageView(uiImage: UIImage) -> some View {
        if uiImage.isAnimated {
            AnimatedImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
        } else {
            StaticImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: image.resizingMode,
                size: estimatedImageSize
            )
        }
    }
#endif
    
    private var inlineImage: UIImage? {
        switch colorScheme {
        case .dark:
            if let inlineImage = image.darkModeInlineImage {
                return inlineImage
            }
            
            fallthrough
        default:
            return image.inlineImage
        }
    }
    
    private var urlString: String? {
        switch colorScheme {
        case .dark:
            if let url = image.darkModeImageURL {
                return url
            }
            
            fallthrough
        default:
            return image.imageURL
        }
    }

    
    private var estimatedImageSize: CGSize? {
        var result: CGSize
        if let dimensions = image.dimensions {
            result = CGSize(
                width: dimensions.width * scale,
                height: dimensions.height * scale)
            return result
        }
        
        if colorScheme == .dark, let width = image.darkModeImageWidth, let height = image.darkModeImageHeight {
            result = CGSize(
                width: width == 0 ? 1 : width,
                height: height == 0 ? 1 : height
            )
        } else if let width = image.imageWidth, let height = image.imageHeight {
            result = CGSize(
                width: width == 0 ? 1 : width,
                height: height == 0 ? 1 : height
            )
        } else {
            return nil
        }
        
        result.width *= scale
        result.height *= scale
        return result
    }
    
    private var scale: CGFloat {
        guard image.resolution > 0 else {
            return 1
        }
        
        return CGFloat(1) / image.resolution
    }
}

private extension UIImage {
    var isAnimated: Bool {
        (self.images?.count).map { $0 > 1 } ?? false
    }
}

// MARK: - StaticImageView

private struct StaticImageView: View {
    var uiImage: UIImage
    var scale: CGFloat
    var resizingMode: RoverExperiences.Image.ResizingMode
    var size: CGSize?
    
    var body: some View {
        switch resizingMode {
        case .originalSize:
            SwiftUI.Image(uiImage: uiImage)
                .resizable()
                .frame(
                    width: frameSize.width,
                    height: frameSize.height
                )
        case .scaleToFill:
                SwiftUI.Rectangle().fill(Color.clear)
                    .overlay(
                        SwiftUI.Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
        case .scaleToFit:
            SwiftUI.Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        case .tile:
            TilingImage(uiImage: uiImage, scale: scale)
        case .stretch:
            SwiftUI.Image(uiImage: uiImage).resizable()
        }
    }
    
    private var frameSize: CGSize {
        if let size = size {
            return size
        } else {
            return CGSize(
                width: uiImage.size.width * scale,
                height: uiImage.size.height * scale
            )
        }
    }
}

// MARK: - AnimatedImage

private struct AnimatedImageView: View {
    var uiImage: UIImage
    var scale: CGFloat
    var resizingMode: RoverExperiences.Image.ResizingMode
    var size: CGSize?

    var body: some View {
        switch resizingMode {
        case .originalSize:
            AnimatedImage(uiImage: uiImage)
                .frame(
                    width: frameSize.width,
                    height: frameSize.height
                )
        case .scaleToFill:
            SwiftUI.Rectangle().fill(Color.clear)
                .overlay(
                    AnimatedImage(uiImage: uiImage)
                        .scaledToFill()
                )
                .clipped()
        case .scaleToFit:
            AnimatedImage(uiImage: uiImage)
                .scaledToFit()
                .clipped()
        case .tile:
            // Tiling animated images is not supported -- fallback to static image.
            TilingImage(uiImage: uiImage, scale: scale)
        case .stretch:
            AnimatedImage(uiImage: uiImage)
        }
    }

    private var frameSize: CGSize {
        if let size = size {
            return size
        } else {
            return CGSize(
                width: uiImage.size.width * scale,
                height: uiImage.size.height * scale
            )
        }
    }
}

// MARK: - AccessibleAnimatedImage

#if compiler(>=5.9)
@available(iOS 17.0, *)
private struct AccessibleAnimatedImageView: View {
    @Environment(\.accessibilityPlayAnimatedImages) private var playAnimatedImages
    
    var uiImage: UIImage
    var scale: CGFloat
    var resizingMode: RoverExperiences.Image.ResizingMode
    var size: CGSize?

    var body: some View {
        if uiImage.isAnimated && playAnimatedImages {
            AnimatedImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: resizingMode,
                size: size
            )
        } else {
            StaticImageView(
                uiImage: uiImage,
                scale: scale,
                resizingMode: resizingMode,
                size: size
            )
        }
    }
}
#endif

// MARK: - TilingImage

private struct TilingImage: View {
    var uiImage: UIImage

    var scale: CGFloat

    var body: some View {
        // tiling only uses the UIImage scale, it cannot be applied after .scaleEffect. so, generate a suitably large tiled image at the default 1x scale, and then scale the entire results down afterwards.
        if #available(iOS 14.0, *) {
            GeometryReader { geometry in
                SwiftUI.Image(uiImage: uiImage)
                    .resizable(resizingMode: .tile)
                    // make sure enough tile is generated to accommodate the scaleEffect below.
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
        } else {
            // we cannot reliably use GeometryReader in all contexts on iOS 13, so instead, we'll just generate a default amount of tile that will accomodate most situations rather than the exact amount. this will waste some vram.
            SwiftUI.Rectangle()
                .fill(Color.clear)
                .overlay(
                    SwiftUI.Image(uiImage: uiImage)
                        .resizable(resizingMode: .tile)
                        // make sure enough tile is generated to accommodate the scaleEffect below.
                        .frame(
                            width: 600,
                            height: 1000
                        )
                    ,
                    alignment: .topLeading
                )
                .clipped()
        }
    }
}


// MARK: - PlaceholderView


private struct PlaceholderView: View {
    var blurHash: String?
    var scale: CGFloat
    var resizingMode: RoverExperiences.Image.ResizingMode
    var size: CGSize?
    
    @ViewBuilder
    var body: some View {
        if #available(iOS 14.0, *) {
            dummyView.redacted(reason: .placeholder)
        } else {
            dummyView
        }
    }
    
    /// A clear, dummy view that mimics the sizing behaviour of the image.
    @ViewBuilder
    private var dummyView: some View {
        switch resizingMode {
        case .originalSize:
            SwiftUI.Rectangle()
                .fill(Color.clear)
                .frame(width: size?.width, height: size?.height)
        case .scaleToFill:
            SwiftUI.Rectangle().fill(Color.clear)
        case .scaleToFit:
            SwiftUI.Rectangle()
                .fill(Color.clear)
                .aspectRatio(aspectRatio, contentMode: ContentMode.fit)
        case .tile:
            SwiftUI.Rectangle().fill(Color.clear)
        case .stretch:
            SwiftUI.Rectangle().fill(Color.clear)
        }
    }
    
    private var aspectRatio: CGFloat {
        let ratio = CGFloat(size?.width ?? 1) / CGFloat(size?.height ?? 1)
        if ratio.isNaN || ratio.isInfinite {
            return 1
        } else {
            return ratio
        }
    }
}

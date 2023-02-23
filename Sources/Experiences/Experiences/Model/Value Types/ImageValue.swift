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

import CryptoKit
import os.log
import UniformTypeIdentifiers
import UIKit

public struct ImageValue: Equatable {
    public static var empty: ImageValue {
        ImageValue(data: Data(), imageType: .png, uiImage: UIImage())
    }

    public enum ImageType: String, CaseIterable {
        case gif = "com.compuserve.gif"
        case jpg = "public.jpeg"
        case png = "public.png"
    }
    
    public var uti: String {
        imageType.rawValue
    }
    
    public let imageType: ImageType
    public let data: Data
    public let uiImage: UIImage
    
    public init?(data: Data) {
        guard let imageSource = CGImageSourceCreateWithData(data as NSData, nil),
              let imageSourceType = CGImageSourceGetType(imageSource),
              let imageType = ImageType(rawValue: imageSourceType as String) else {
            return nil
        }

        let animated = CGImageSourceGetCount(imageSource) > 1

        if !animated {
            guard let uiImage = UIImage(data: data) else {
                return nil
            }
            uiImage.imageAsset?.register(uiImage, with: UITraitCollection(displayScale: 1.0))
            uiImage.imageAsset?.register(UIImage(data: data, scale: 2.0)!, with: UITraitCollection(displayScale: 2.0))
            uiImage.imageAsset?.register(UIImage(data: data, scale: 3.0)!, with: UITraitCollection(displayScale: 3.0))
            self.init(data: data, imageType: imageType, uiImage: uiImage)
        } else {

            var images: [UIImage] = []
            var duration: Double = 0

            for imageIdx in 0..<CGImageSourceGetCount(imageSource) {
                if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, imageIdx, nil) {
                    let image = UIImage(cgImage: cgImage)
                    image.imageAsset?.register(image, with: UITraitCollection(displayScale: 1.0))
                    image.imageAsset?.register(UIImage(cgImage: cgImage, scale: 2.0, orientation: .up), with: UITraitCollection(displayScale: 2.0))
                    image.imageAsset?.register(UIImage(cgImage: cgImage, scale: 3.0, orientation: .up), with: UITraitCollection(displayScale: 3.0))
                    images.append(image)
                    duration += imageSource.gifAnimationDelay(imageAtIndex: imageIdx)
                }
            }
            guard let uiImage = UIImage.animatedImage(with: images, duration: round(duration * 10.0) / 10.0) else {
                return nil
            }

            self.init(data: data, imageType: imageType, uiImage: uiImage)
        }
    }
    
    private init(data: Data, imageType: ImageType, uiImage: UIImage) {
        self.data = data
        self.imageType = imageType
        self.uiImage = uiImage
    }
}

private extension CGImageSource {
    func gifAnimationDelay(imageAtIndex imageIdx: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(self, imageIdx, nil) as? [String:Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return 0.1
        }

        if let unclampedDelayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
            return unclampedDelayTime.isZero ? 0.1 : unclampedDelayTime
        } else if let gifDelayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
            return gifDelayTime.isZero ? 0.1 : gifDelayTime
        }
        return 0.1
    }
}

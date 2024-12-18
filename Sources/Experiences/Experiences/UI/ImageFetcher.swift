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
import RoverFoundation

struct ImageFetcher<Content, Placeholder>: View where Content: View, Placeholder: View {
    var url: URL
    var content: (UIImage) -> Content
    var placeholder: Placeholder

    private enum FetchState: Equatable {
        case loading
        case loaded(uiImage: UIImage)
        case failed
    }

    @State private var uiImage: UIImage?

    init(url: URL, @ViewBuilder content: @escaping (UIImage) -> Content, placeholder: () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder()
    }

    var body: some View {
        if let uiImage = uiImage {
            content(uiImage)
                .onValueChanged(of: url) { url in
                    startFetch(url: url)
                }
        } else {
            placeholder.onAppear {
                startFetch(url: url)
            }
        }
    }

    private func startFetch(url: URL) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!

        func setState(_ state: FetchState) {
            switch state {
            case .loaded(let uiImage):
                DispatchQueue.main.async {
                    withAnimation {
                        self.uiImage = uiImage
                    }
                }
                
            case .failed:
                DispatchQueue.main.async {
                    withAnimation {
                        self.uiImage = nil
                    }
                }
                
            default:
                return
            }
        }
        
        if let cachedImage = ExperienceManager.getCachedImage(for: url) {
            setState(.loaded(uiImage: cachedImage))
            return
        }

        experienceManager.downloader.download(url: url) { result in
            switch result {
            case let .failure(error):
                rover_log(.error, "Failed to fetch image data: %@", (error as NSError).userInfo.debugDescription)
                setState(.failed)
                return
            case let .success(data):
                experienceManager.imageFetchAndDecodeQueue.async {
                    guard let decoded = data.loadUIImage() else {
                        rover_log(.error, "Failed to decode image data.")
                        setState(.failed)
                        return
                    }

                    DispatchQueue.main.async {
                        experienceManager.imageCache.setObject(decoded, forKey: url as NSURL)
                    }

                    setState(.loaded(uiImage: decoded))
                }
            }
        }
    }
}


private extension Data {
    func loadUIImage() -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }

        let animated = CGImageSourceGetCount(imageSource) > 1

        if !animated {
            guard let uiImage = UIImage(data: self, scale: 1.0) else {
                return nil
            }

            return uiImage
        }

        var images: [UIImage] = []
        var duration: Double = 0

        for imageIdx in 0..<CGImageSourceGetCount(imageSource) {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, imageIdx, nil) {
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                images.append(image)
                duration += imageSource.gifAnimationDelay(imageAtIndex: imageIdx)
            }
        }

        guard let uiImage = UIImage.animatedImage(with: images, duration: round(duration * 10.0) / 10.0) else {
            return nil
        }

        return uiImage
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

private extension ExperienceManager {
    static func getCachedImage(for imageUrl: URL) -> UIImage? {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        
        // look in the image cache for an already decoded and in-memory copy.
        if let cachedImage = experienceManager.imageCache.object(forKey: imageUrl as NSURL) {
            return cachedImage
        }

        // look in the HTTP cache for already downloaded copy if this is a smaller image, in order to avoid the async path (with a delay and animation) if an unexpired copy is present in the cache.
        if let cacheEntry = experienceManager.assetsURLCache.cachedResponse(for: URLRequest(url: imageUrl)) {
            // when displaying the image directly from the cache, then just decode it synchronously on the main thread, blocking rendering: this is desirable to avoid a bit of async state for occurring while waiting for a decode to complete. The tradeoff changes for larger images (especially things like animated GIFs) which we'll fall back to decoding asynchronously on a background queue.
            if cacheEntry.data.count < 524288 {
                if let decoded = cacheEntry.data.loadUIImage() {
                    experienceManager.imageCache.setObject(decoded, forKey: imageUrl as NSURL)
                    return decoded
                } else {
                    rover_log(.error, "Failed to decode presumably corrupted cached image data. Removing it to allow for re-fetch.")
                    experienceManager.urlCache.removeCachedResponse(for: URLRequest(url: imageUrl))
                }
            }
        }
        
        return nil
    }
}

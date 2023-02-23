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

import UIKit

public extension URLCache {
    static func makeRoverDefaultCache() -> URLCache {
        let cacheURL = try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("RoverCache", isDirectory: true)

        return URLCache(memoryCapacity: 1_048_576 * 64, diskCapacity: 1_048_576 * 256, directory: cacheURL)
    }

    static func makeRoverAssetsDefaultCache() -> URLCache {
        let cacheURL = try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("RoverAssetsCache", isDirectory: true)

        return URLCache(memoryCapacity: 1_048_576 * 64, diskCapacity: 1_048_576 * 256, directory: cacheURL)
    }
}

public extension NSCache {
    @objc static func roverDefaultImageCache() -> NSCache<NSURL, UIImage> {
        let c = NSCache<NSURL, UIImage>()
        c.totalCostLimit = 40
        c.name = "Rover Image Cache"
        return c
    }
}

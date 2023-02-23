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

import CoreGraphics
import Foundation

public struct ImageConfiguration {
    public let url: URL
    public let optimization: ImageOptimization?
    
    public var optimizedURL: URL {
        guard let optimization = optimization else {
            return url
        }
        
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        var temp = urlComponents.queryItems ?? [URLQueryItem]()
        temp += optimization.queryItems
        urlComponents.queryItems = temp
        return urlComponents.url ?? url
    }
    
    public var scale: CGFloat {
        return optimization?.scale ?? 1
    }
    
    public init(url: URL, optimization: ImageOptimization? = nil) {
        self.url = url
        self.optimization = optimization
    }
}

extension ImageConfiguration: Equatable {
    public static func == (lhs: ImageConfiguration, rhs: ImageConfiguration) -> Bool {
        return lhs.optimizedURL == rhs.optimizedURL
    }
}

extension ImageConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(optimizedURL.hashValue)
    }
}

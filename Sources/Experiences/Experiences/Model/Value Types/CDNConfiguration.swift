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

public struct CDNConfiguration: Decodable {
    public let imageLocation: String
    public let mediaLocation: String
    public let fontLocation: String
    
    public init(imageLocation: String, mediaLocation: String, fontLocation: String) {
        self.imageLocation = imageLocation
        self.mediaLocation = mediaLocation
        self.fontLocation = fontLocation
    }
    
    /// Initialize CDN Configuration from data (JSON)
    /// - Parameter data: Configuration data.
    /// - Throws: Throws error on failure.
    public init(decode data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
    
    private enum CodingKeys: String, CodingKey {
        case imageLocation
        case mediaLocation
        case fontLocation
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let imageLocation = try container.decode(String.self, forKey: .imageLocation)
        let mediaLocation = try container.decode(String.self, forKey: .mediaLocation)
        let fontLocation = try container.decode(String.self, forKey: .fontLocation)
        self.init(imageLocation: imageLocation, mediaLocation: mediaLocation, fontLocation: fontLocation)
    }
}

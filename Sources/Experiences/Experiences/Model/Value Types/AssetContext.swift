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

public enum AssetType {
    case image
    case media
    case font
}

public protocol AssetContext {
    func assetUrl(for assetType: AssetType, name: String) -> URL
}


//the CDN configuration will need to be checked here, but at the same time, if it isn't present, a default URL will need to be used.

public struct RemoteAssetContext: AssetContext {
    let baseUrl: URL
    let configuration: CDNConfiguration?
    
    public init(baseUrl: URL, configuration: CDNConfiguration?) {
        self.baseUrl = baseUrl
        self.configuration = configuration
    }
    
    public func assetUrl(for assetType: AssetType, name: String) -> URL {
        if let configuration = configuration {
            return configuration.locationForAsset(assetType: assetType, name: name)
        }
        
        let foldername = {
            switch assetType {
            case .image:
                return "images"
            case .media:
                return "media"
            case .font:
                return "fonts"
            }
        }()
        
        var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)!
        urlComponents.path += "/" + foldername + "/" + name
        
        guard let url = urlComponents.url else {
            fatalError("Malformed base or file URL.")
        }
        return url
    }
}

public struct LocalAssetContext: AssetContext {
    public let mediaURLs: Set<URL>
    public let fontURLs: Set<URL>
    
    public func assetUrl(for assetType: AssetType, name: String) -> URL {
        switch assetType {
        case.image:
            //This is a consequence of images being extracted into memory, rather than on the filesystem.  There are no local image files to point to.
            fatalError("Local asset contexts do not support local images, as there are none on the filesystem.")
      
        case .media:
            guard let mediaUrl = mediaURLs.first(where: { $0.lastPathComponent == name }) else {
                fatalError("Media file not found.")
            }
            return mediaUrl
            
        case .font:
            guard let fontUrl = fontURLs.first(where: { $0.lastPathComponent == name }) else {
                fatalError("Font file not found.")
            }
            return fontUrl
        }
    }
    
    public init(mediaURLs: Set<URL>, fontURLs: Set<URL>) {
        self.mediaURLs = mediaURLs
        self.fontURLs = fontURLs
    }
}

fileprivate extension CDNConfiguration {
    func locationForAsset(assetType: AssetType, name: String) -> URL {
        return {
            switch assetType {
            case .image:
                guard let url = URL(string: self.imageLocation.replacingOccurrences(of: "{name}", with: name)) else {
                    fatalError("Malformed image asset or configuration URL.")
                }
                return url
                
            case .media:
                guard let url = URL(string: self.mediaLocation.replacingOccurrences(of: "{name}", with: name)) else {
                    fatalError("Malformed media asset or configuration URL.")
                }
                return url
                
            case .font:
                guard let url = URL(string: self.fontLocation.replacingOccurrences(of: "{name}", with: name)) else {
                    fatalError("Malformed font or configuration URL.")
                }
                return url
            }
        }()
    }
}

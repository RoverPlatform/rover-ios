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

public enum ClassicBlockTapBehavior: Equatable {
    case goToScreen(screenID: String)
    case none
    case openURL(url: URL, dismiss: Bool)
    case presentWebsite(url: URL)
    case custom
}

// MARK: Codable

extension ClassicBlockTapBehavior: Codable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    private enum GoToScreenKeys: String, CodingKey {
        case screenID
    }
    
    private enum OpenURLKeys: String, CodingKey {
        case url
        case dismiss
    }
    
    private enum PresentWebsiteKeys: String, CodingKey {
        case url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "GoToScreenBlockTapBehavior":
            let container = try decoder.container(keyedBy: GoToScreenKeys.self)
            let screenID = try container.decode(String.self, forKey: .screenID)
            self = .goToScreen(screenID: screenID)
        case "NoneBlockTapBehavior":
            self = .none
        case "OpenURLBlockTapBehavior":
            let container = try decoder.container(keyedBy: OpenURLKeys.self)
            let url = try container.decode(URL.self, forKey: .url)
            let dismiss = try container.decode(Bool.self, forKey: .dismiss)
            self = .openURL(url: url, dismiss: dismiss)
        case "PresentWebsiteBlockTapBehavior":
            let container = try decoder.container(keyedBy: PresentWebsiteKeys.self)
            let url = try container.decode(URL.self, forKey: .url)
            self = .presentWebsite(url: url)
        case "CustomBlockTapBehavior":
            self = .custom
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of GoToScreenBlockTapBehavior, NoneBlockTapBehavior, OpenURLBlockTapBehavior or PresentWebsiteBlockTapBehavior – found \(typeName)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .goToScreen(let screenID):
            try container.encode("GoToScreenBlockTapTapBehavior", forKey: .typeName)
            var container = encoder.container(keyedBy: GoToScreenKeys.self)
            try container.encode(screenID, forKey: .screenID)
        case .none:
            try container.encode("NoneBlockTapBehavior", forKey: .typeName)
        case let .openURL(url, dismiss):
            try container.encode("OpenURLBlockTapTapBehavior", forKey: .typeName)
            var container = encoder.container(keyedBy: OpenURLKeys.self)
            try container.encode(url, forKey: .url)
            try container.encode(dismiss, forKey: .dismiss)
        case .presentWebsite(let url):
            try container.encode("PresentWebsiteBlockTapBehavior", forKey: .typeName)
            var container = encoder.container(keyedBy: PresentWebsiteKeys.self)
            try container.encode(url, forKey: .url)
        case .custom:
            try container.encode("CustomBlockTapBehavior", forKey: .typeName)
        }
    }
}

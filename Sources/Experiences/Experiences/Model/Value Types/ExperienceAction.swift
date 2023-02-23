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

public enum ExperienceAction: Decodable, Hashable {
    case performSegue
    case openURL(url: String, dismissExperience: Bool)
    case presentWebsite(url: String)
    case close
    case custom(dismissExperience: Bool)
    
    // MARK: Decodable
    
    private enum CodingKeys: String, CodingKey {
        case caseName = "__caseName"
        case screenID
        case style
        case url
        case dismissExperience
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseName = try container.decode(String.self, forKey: .caseName)
        switch caseName {
        case "performSegue":
            self = .performSegue
        case "openURL":
            let url = try container.decode(String.self, forKey: .url)
            let dismissExperience = try container.decode(Bool.self, forKey: .dismissExperience)
            self = .openURL(url: url, dismissExperience: dismissExperience)
        case "presentWebsite":
            let url = try container.decode(String.self, forKey: .url)
            self = .presentWebsite(url: url)
        case "custom":
            let dismissExperience = try container.decode(Bool.self, forKey: .dismissExperience)
            self = .custom(dismissExperience: dismissExperience)
        case "close":
            self = .close
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .caseName,
                in: container,
                debugDescription: "Invalid value: \(caseName)"
            )
        }
    }
}

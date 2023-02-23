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

public struct ClassicExperienceModel {
    public var id: String
    public var name: String
    public var homeScreen: ClassicScreen
    public var screens: [ClassicScreen]
    public var keys: [String: String]
    public var tags: [String]
    
    public init(id: String, name: String, homeScreen: ClassicScreen, screens: [ClassicScreen], keys: [String: String], tags: [String]) {
        self.id = id
        self.name = name
        self.homeScreen = homeScreen
        self.screens = screens
        self.keys = keys
        self.tags = tags
    }
}

// MARK: Decodable

extension ClassicExperienceModel: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case campaignID
        case homeScreenID
        case screens
        case keys
        case tags
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        screens = try container.decode([ClassicScreen].self, forKey: .screens)
        keys = try container.decode([String: String].self, forKey: .keys)
        tags = try container.decode([String].self, forKey: .tags)
        
        let homeScreenID = try container.decode(String.self, forKey: .homeScreenID)
        
        guard let homeScreen = screens.first(where: { $0.id == homeScreenID }) else {
            throw DecodingError.dataCorruptedError(forKey: .homeScreenID, in: container, debugDescription: "No screen found with homeScreenID \(homeScreenID)")
        }
        
        self.homeScreen = homeScreen
    }
}

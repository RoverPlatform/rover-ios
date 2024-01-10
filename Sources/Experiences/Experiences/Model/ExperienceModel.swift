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

final class ExperienceModel: Decodable {
    enum Appearance: String, Decodable {
        case light
        case dark
        case auto
    }
    
    /// A unique identifier for the Experience.
    var id: String?
    var name: String?
    
    var screens = [Screen]()
    var initialScreen: Screen?
    var segues = [Segue]()
    var colors = [DocumentColor]()
    var gradients = [DocumentGradient]()
    var localization = StringTable()
    var fonts = [DocumentFont]()
    
    /// Font download URLs
    var fontURLs: [URL] {
        fonts.flatMap { $0.sources.map {$0.assetUrl} }
    }
    var appearance = Appearance.auto
    
    var urlParameters: [String: String] = [:]
    var userInfo: [String: Any] = [:]
    var authorizers = [DocumentAuthorizer]()
    
    /// A set of nodes contained in the document. Use `initialScreenID` to determine the initial node to render.
    var nodes: [Node] {
        return screens as [Node]
    }
    
    /// The ID of the initial node to render.
    var initialScreenID: Screen.ID {
        return initialScreen!.id
    }
    
    var sourceUrl: URL?

    /// Initialize Experience from data (JSON)
    /// - Parameter data: Experience data.
    /// - Throws: Throws error on failure.
    static func decode(from data: Data,
                              name: String? = nil,
                              id: String? = nil,
                              images: [String: ImageValue]? = nil,
                              assetContext: AssetContext) throws -> ExperienceModel {
        let decoder = JSONDecoder()
        //TODO: handle document version properly, rather than hard coding it or using magic numbers
        let coordinator = DecodingCoordinator(documentVersion: 7, images: images)
        decoder.userInfo[.decodingCoordinator] = coordinator
        decoder.userInfo[.assetContext] = assetContext
        decoder.userInfo[.experienceName] = name
        decoder.userInfo[.experienceId] = id
        return try decoder.decode(Self.self, from: data)
    }


    enum CodingKeys: String, CodingKey {
        case id
        case name
        case revisionID
        case nodes
        case screenIDs
        case initialScreenID
        case segues
        case colors
        case gradients
        case fonts
        case mediaURLs
        case fontURLs
        case appearance
        case urlParameters
        case userInfo
        case authorizers
        case localizations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordinator = decoder.userInfo[.decodingCoordinator] as! DecodingCoordinator
        
        if let experienceId = decoder.userInfo[.experienceId] as? String {
            id = experienceId
        } else {
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }
        
        if let experienceName = decoder.userInfo[.experienceName] as? String {
            name = experienceName
        } else {
            name = try container.decodeIfPresent(String.self, forKey: .name)
        }
        
        segues = try container.decode([Segue].self, forKey: .segues)
        colors = try container.decode([DocumentColor].self, forKey: .colors)
        gradients = try container.decode([DocumentGradient].self, forKey: .gradients)
        fonts = try container.decode([DocumentFont].self, forKey: .fonts)
        localization = try container.decode(StringTable.self, forKey: .localizations)
        appearance = try container.decode(Appearance.self, forKey: .appearance)
        
        let parameterArray = try container.decode([String].self, forKey: .urlParameters)
        self.urlParameters = parameterArray.toStringDictionary()
        
        let userArray = try container.decode([String].self, forKey: .userInfo)
        self.userInfo = userArray.toStringDictionary()
        
        authorizers = try container.decode([DocumentAuthorizer].self, forKey: .authorizers)

        coordinator.registerOneToManyRelationship(
            nodeIDs: try container.decode([Node.ID].self, forKey: .screenIDs),
            to: self,
            keyPath: \.screens
        )
        
        if container.contains(.initialScreenID) {
            coordinator.registerOneToOneRelationship(
                nodeID: try container.decode(Node.ID.self, forKey: .initialScreenID),
                to: self,
                keyPath: \.initialScreen
            )
        }
        
        let nodes = try container.decodeNodes(forKey: .nodes)
        try coordinator.resolveRelationships(nodes: nodes, documentColors: colors, documentGradients: gradients)
    }
}

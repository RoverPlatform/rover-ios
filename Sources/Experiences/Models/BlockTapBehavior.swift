//
//  BlockTapBehavior.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum BlockTapBehavior {
    case goToScreen(screenID: ID)
    case none
    case openURL(url: URL, dismiss: Bool)
    case presentWebsite(url: URL)
}

// MARK: AttributeRepresentable

extension BlockTapBehavior: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        switch self {
        case .goToScreen(let screenID):
            return [
                "type": "goToScreen",
                "screenID": screenID
            ]
        case .none:
            return [
                "type": "none"
            ]
        case .openURL(let url, _):
            return [
                "type": "openURL",
                "url": url
            ]
        case .presentWebsite(let url):
            return [
                "type": "presentWebsite",
                "url": url
            ]
        }
    }
}

// MARK: Codable

extension BlockTapBehavior: Codable {
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
            let screenID = try container.decode(ID.self, forKey: .screenID)
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
        }
    }
}

//
//  ExperienceConversionsManager.swift
//  RoverExperiences
//
//  Created by Chris Recalis on 2020-06-25.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//
import Foundation
import os.log
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class ExperienceConversionsManager: ConversionsContextProvider {
    private let persistedConversions = PersistedValue<Set<Tag>>(storageKey: "io.rover.RoverExperiences.conversions")
    var conversions: [String]? {
        return self.persistedConversions.value?.filter{ $0.expiresAt > Date() }.map{ $0.rawValue }
    }
    
    func track(_ tag: String, _ expiresIn: TimeInterval) {
        var result = (self.persistedConversions.value ?? []).filter { $0.expiresAt > Date() }
        result.update(with: Tag(
            rawValue: tag,
            expiresAt: Date().addingTimeInterval(expiresIn)
        ))
        self.persistedConversions.value = result
    }
}

private struct Tag: Codable, Equatable, Hashable {
    public static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    
    public var rawValue: String
    public var expiresAt: Date = Date()
}

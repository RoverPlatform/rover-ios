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
import os.log
import RoverFoundation

public class ConversionsManager: ConversionsContextProvider, ConversionsTrackerService {
    private let persistedConversions = PersistedValue<Array<String>>(storageKey: "io.rover.data.conversions")
    
    private let oldPersistedConversions = PersistedValue<Set<LegacyTag>>(storageKey: "io.rover.RoverExperiences.conversions")
    
    public var conversions: [String]? {
        guard let persistedConversions = self.persistedConversions.value else {
            return nil
        }
        
        return Array(persistedConversions.prefix(100))
    }
    
    public func track(_ tag: String) {
        guard var result = self.persistedConversions.value else {
            self.persistedConversions.value = [tag]
            return
        }

        result.removeAll(where: { $0 == tag })
        result.insert(tag, at: 0)
        self.persistedConversions.value = Array(result.prefix(100))
    }
}

//This extension is for converting tags from previous versions of the Rover SDK.
//Will be removed at some point.
internal extension ConversionsManager {
    func migrateTags() {
        guard let oldPersistedConversions = self.oldPersistedConversions.value else {
            return
        }
        
        let sortedConversions = oldPersistedConversions.sorted {
            $0.expiresAt > $1.expiresAt
        }.prefix(100)

        for tag in sortedConversions {
            track(tag.rawValue)
        }
        
        self.oldPersistedConversions.value = nil
    }
    
    private struct LegacyTag: Codable, Equatable, Hashable {
        public static func == (lhs: LegacyTag, rhs: LegacyTag) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue)
        }
        
        public var rawValue: String
        public var expiresAt: Date = Date()
    }
}

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
import RoverData

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

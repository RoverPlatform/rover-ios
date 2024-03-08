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

import SwiftUI

final class Carousel: Layer {
    /// Indicates whether the Carousel continually wraps around to the first/last elements as you scroll.
    public let isLoopEnabled: Bool
    public let isStoryStyleEnabled: Bool
    public let storyAutoAdvanceDuration: Int
    
    public init(id: String = UUID().uuidString, name: String?, parent: Node? = nil, children: [Node] = [], ignoresSafeArea: Set<Edge>? = nil, aspectRatio: CGFloat? = nil, padding: Padding? = nil, frame: Frame? = nil, layoutPriority: CGFloat? = nil, offset: CGPoint? = nil, shadow: Shadow? = nil, opacity: CGFloat? = nil, background: Background? = nil, overlay: Overlay? = nil, mask: Node? = nil, action: ExperienceAction? = nil, accessibility: Accessibility? = nil, metadata: Metadata? = nil, isLoopEnabled: Bool, isStoryStyleEnabled: Bool, storyAutoAdvanceDuration: Int) {
        self.isLoopEnabled = isLoopEnabled
        self.isStoryStyleEnabled = isStoryStyleEnabled
        self.storyAutoAdvanceDuration = storyAutoAdvanceDuration
        super.init(id: id, name: name, parent: parent, children: children, ignoresSafeArea: ignoresSafeArea, aspectRatio: aspectRatio, padding: padding, frame: frame, layoutPriority: layoutPriority, offset: offset, shadow: shadow, opacity: opacity, background: background, overlay: overlay, mask: mask, action: action, accessibility: accessibility, metadata: metadata)
    }

    // MARK: Decodable
    
    private enum CodingKeys: String, CodingKey {
        case isLoopEnabled
        case isAutoAdvanceEnabled
        case autoAdvanceDuration
        case isRememberPositionEnabled
        case isStoryStyleEnabled
        case storyAutoAdvanceDuration
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isLoopEnabled = try container.decode(Bool.self, forKey: .isLoopEnabled)
        
        //Introduced in document version 16
        if let isStoryStyleEnabled = try container.decodeIfPresent(Bool.self, forKey: .isStoryStyleEnabled) {
            self.isStoryStyleEnabled = isStoryStyleEnabled
        } else if let isAutoAdvanceEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoAdvanceEnabled) {
            //Upgraded from document version 14
            self.isStoryStyleEnabled = isAutoAdvanceEnabled
        } else {
            isStoryStyleEnabled = false
        }
        
        //Introduced in document version 16
        if let storyAutoAdvanceDuration = try container.decodeIfPresent(Int.self, forKey: .storyAutoAdvanceDuration) {
            self.storyAutoAdvanceDuration = storyAutoAdvanceDuration
        } else if let storyAutoAdvanceDuration = try container.decodeIfPresent(Int.self, forKey: .autoAdvanceDuration) {
            //Upgraded from document version 14
            self.storyAutoAdvanceDuration = storyAutoAdvanceDuration
        } else {
            storyAutoAdvanceDuration = 0
        }

        try super.init(from: decoder)
    }
}

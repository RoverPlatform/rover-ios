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

import RoverData
import RoverFoundation

extension EventInfo {
    static func screenViewedEvent(
        with campaignID: String?,
        experience: ExperienceModel,
        screen: Screen
    ) -> EventInfo {
        let experienceAttributes = ["id": experience.id,
                                    "name": experience.name ?? "Name",
                                    "campaignID": campaignID,
                                    "url": experience.sourceUrl?.absoluteString]
            .compactMapValues { $0 }
        
        return EventInfo(
            name: "Experience Screen Viewed",
            namespace: "rover",
            attributes: [
                "experience" : experienceAttributes,
                "screen" : [
                    "id": screen.id,
                    "name": screen.name ?? "Name"]
            ])
    }
    
    static func experienceButtonTappedEvent(
        with campaignID: String?,
        experience: ExperienceModel,
        screen: Screen,
        node: Node
    ) -> EventInfo {
        let experienceAttributes = ["id": experience.id,
                                    "name": experience.name,
                                    "campaignID": campaignID,
                                    "url": experience.sourceUrl?.absoluteString]
            .compactMapValues { $0 }
        
        let screenAttributes = ["id": screen.id,
                                "name": screen.name]
            .compactMapValues { $0 }
        
        let nodeAttributes = ["id": node.id,
                              "name": node.name]
            .compactMapValues { $0 }
        
        return EventInfo(
            name: "Experience Button Tapped",
            namespace: "rover",
            attributes: [
                "experience" : experienceAttributes,
                "screen" : screenAttributes,
                "node" : nodeAttributes,
            ])
    }
    
    static func carouselViewedEvent(
        with campaignID: String?,
        experience: ExperienceModel,
        carousel: Carousel,
        position: Int
    ) -> EventInfo {
        let experienceAttributes = ["id": experience.id,
                                    "name": experience.name,
                                    "campaignID": campaignID,
                                    "url": experience.sourceUrl?.absoluteString]
            .compactMapValues { $0 }
        
        let carouselAttributes: Attributes = [
            "id": carousel.id,
            "storyStyle": carousel.isStoryStyleEnabled,
            "loop": carousel.isLoopEnabled]
        
        return EventInfo(
            name: "Carousel Page Viewed",
            namespace: "rover",
            attributes: [
                "experience": experienceAttributes,
                "carousel": carouselAttributes,
                "position": position
            ]
        )
    }
}

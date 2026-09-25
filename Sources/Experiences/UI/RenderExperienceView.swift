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

import RoverFoundation
import SwiftUI
import os.log

/// Renders an Experience within an external SwiftUI `NavigationStack`.
///
/// This view participates in an external navigation flow via the `path` binding, unlike
/// `RenderExperienceViewController` which manages its own UIKit `UINavigationController` internally.
///
/// Used internally by `ExperienceView`.
///
/// - Note: This view is used exclusively by the Hub. It is not part of
///   the standard Rover Experiences rendering path used by `RoverExperiences` elsewhere in the SDK.
struct RenderExperienceView: View {

    let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
    var experience: ExperienceModel
    var urlParameters: [String: String]
    var userInfo: [String: Any]
    var authorizers: Authorizers
    @Binding var path: NavigationPath

    @StateObject private var fontLoader: FontLoader
    @StateObject private var carouselState: CarouselState

    init(
        experience: ExperienceModel,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorizers: Authorizers,
        path: Binding<NavigationPath>
    ) {
        self.experience = experience
        self.urlParameters = urlParameters
        self.userInfo = userInfo
        self.authorizers = authorizers
        self._path = path
        let carouselState = CarouselState(experienceUrl: experience.sourceUrl?.absoluteString)
        self._carouselState = StateObject(wrappedValue: carouselState)
        self._fontLoader = StateObject(wrappedValue: FontLoader(experience: experience))
    }

    var body: some View {
        SwiftUI.ZStack {
            if let screen {
                ScreenView(
                    experience: experience,
                    screen: screen,
                    data: nil,
                    urlParameters: urlParameters,
                    userInfo: userInfo,
                    authorizers: authorizers,
                    carouselState: carouselState,
                    experienceManager: experienceManager,
                    path: $path
                )
            } else {
                SwiftUI.Text("Unable to find screen")
            }
        }
        .navigationDestination(for: ScreenDestination.self) { destination in
            ScreenView(
                experience: experience,
                screen: destination.screen,
                data: destination.data,
                urlParameters: urlParameters,
                userInfo: userInfo,
                authorizers: authorizers,
                carouselState: carouselState,
                experienceManager: experienceManager,
                path: $path
            )
        }
        .onAppear {
            experienceManager.observeScreenViews()
        }
    }

    var screen: Screen? {
        let initialScreenID = experience.initialScreenID

        // determine which root container is on the path to the initial screen:
        let matchingScreen = experience.nodes.first(where: { $0.id == initialScreenID }) as? Screen

        guard let initialScreen = matchingScreen ?? experience.nodes.first(where: { $0 is Screen }) as? Screen else {
            rover_log(.error, "No screen to start the Experience from. Giving up.")
            return nil
        }
        return initialScreen
    }
}

// Convenience Object to load the Fonts
private class FontLoader: ObservableObject {
    init(experience: ExperienceModel) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        // Register experience fonts
        ExperienceFontLoader.loadFonts(for: experience, experienceManager: experienceManager)
    }
}

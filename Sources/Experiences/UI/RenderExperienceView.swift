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
        experience.fontURLs.forEach { url in
            if url.isFileURL {
                do {
                    let fontData = try Data(contentsOf: url)
                    try Self.registerFontIfNeeded(data: fontData)
                } catch {
                    rover_log(
                        .error,
                        "Failed to decode presumably corrupted cached font data. Font will not be loaded.  Error: %s",
                        error.debugDescription)
                }
            } else {
                experienceManager.downloader.download(url: url) { result in
                    do {
                        try Self.registerFontIfNeeded(data: result.get())
                    } catch {
                        rover_log(
                            .error,
                            "Failed to decode presumably corrupted cached font data. Removing it to allow for re-fetch. Error: %s",
                            error.debugDescription)
                        experienceManager.assetsURLCache.removeCachedResponse(for: URLRequest(url: url))
                    }
                }
            }
        }
    }

    private static func registerFontIfNeeded(data: Data) throws {
        struct FontRegistrationError: Swift.Error, LocalizedError {
            let message: String

            var errorDescription: String? {
                message
            }
        }

        guard let fontProvider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(fontProvider),
            let fontName = cgFont.postScriptName as String?
        else {
            throw FontRegistrationError(message: "Unable to register font from provided data.")
        }

        let queryCollection = CTFontCollectionCreateWithFontDescriptors(
            [
                CTFontDescriptorCreateWithAttributes(
                    [kCTFontNameAttribute: fontName] as CFDictionary
                )
            ] as CFArray, nil
        )

        let fontExists =
            (CTFontCollectionCreateMatchingFontDescriptors(queryCollection) as? [CTFontDescriptor])?.isEmpty == false
        if !fontExists {
            if !CTFontManagerRegisterGraphicsFont(cgFont, nil) {
                throw FontRegistrationError(message: "Unable to register font: \(fontName)")
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: ExperienceManager.didRegisterCustomFontNotification, object: fontName)
            }
        }
    }
}

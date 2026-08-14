//
//  NavBarAppearanceReset.swift
//  Rover
//
//  Created by Andrew Marmion on 26/05/2026.
//

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

import RoverExperiences
import SwiftUI

/// Resets the navigation bar `UIAppearance` for this subhierarchy, avoiding
/// inheriting global app appearance settings.
struct NavBarAppearanceReset: UIViewControllerRepresentable {
    /// How the enclosing screen's navigation bar should render once shielded from
    /// the host app's global appearance settings.
    enum Style {
        /// The bar is fully transparent in every state. Used by surfaces that own
        /// their chrome, like the App Screens home view.
        case transparent

        /// The bar is transparent while content is at rest at the top, and shows
        /// the system background material once content scrolls underneath, keeping
        /// the title and back button legible. Used by content screens like the
        /// messages list and the post and conversation detail views.
        case systemScrolledBackground

        /// The appearances this style pins on the enclosing screen's navigation item.
        /// For `.transparent` the scrolled and at-rest configurations are the same
        /// object; `.systemScrolledBackground` uses the system default background for
        /// the scrolled state only.
        func makeAppearances() -> (scrolled: UINavigationBarAppearance, atRest: UINavigationBarAppearance) {
            let atRest = UINavigationBarAppearance()
            atRest.configureWithTransparentBackground()

            switch self {
            case .transparent:
                return (scrolled: atRest, atRest: atRest)
            case .systemScrolledBackground:
                let scrolled = UINavigationBarAppearance()
                scrolled.configureWithDefaultBackground()
                return (scrolled: scrolled, atRest: atRest)
            }
        }
    }

    let style: Style

    func makeUIViewController(context: Context) -> Controller { Controller(style: style) }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController {
        private let style: Style

        init(style: Style) {
            self.style = style
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navigationController = navigationController else {
                return
            }

            resetAppScreensNavigationBar(navigationController.navigationBar)
            resetEnclosingNavigationItem(in: navigationController)
        }

        /// Pins appearances on the `UINavigationItem` of the screen that contains
        /// this controller. UIKit resolves per-item appearances ahead of both the
        /// host app's global `UINavigationBar.appearance()` proxy and bar-instance
        /// state, and they travel with the screen — so unlike the bar-instance reset
        /// above, they survive re-presentation of the Hub and cover navigation bar
        /// instances this controller never sees.
        private func resetEnclosingNavigationItem(in navigationController: UINavigationController) {
            var screen: UIViewController = self
            while let parent = screen.parent, parent !== navigationController {
                screen = parent
            }
            guard screen.parent === navigationController else {
                return
            }

            let (scrolled, atRest) = style.makeAppearances()

            screen.navigationItem.standardAppearance = scrolled
            screen.navigationItem.scrollEdgeAppearance = atRest
            screen.navigationItem.compactAppearance = scrolled
            screen.navigationItem.compactScrollEdgeAppearance = atRest
        }
    }
}

extension View {
    /// Applies `NavBarAppearanceReset` to this view, resetting the navigation bar
    /// `UIAppearance` for the subhierarchy to avoid inheriting global app settings.
    func resetNavBarAppearance(_ style: NavBarAppearanceReset.Style = .transparent) -> some View {
        background(NavBarAppearanceReset(style: style).frame(width: 0, height: 0))
    }
}

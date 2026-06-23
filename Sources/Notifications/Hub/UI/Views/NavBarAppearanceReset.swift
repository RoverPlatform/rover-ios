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

import SwiftUI

/// Resets the navigation bar `UIAppearance` for this subhierarchy, avoiding
/// inheriting global app appearance settings.
struct NavBarAppearanceReset: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let bar = navigationController?.navigationBar else {
                return
            }

            let standard = UINavigationBarAppearance()
            standard.configureWithTransparentBackground()

            bar.standardAppearance = standard
            bar.scrollEdgeAppearance = standard
            bar.compactAppearance = standard
            bar.compactScrollEdgeAppearance = standard

            bar.tintColor = nil
            bar.isTranslucent = true
            bar.backgroundColor = nil
            bar.barStyle = .default
            bar.shadowImage = nil
            bar.setBackgroundImage(nil, for: .default)
            bar.setBackgroundImage(nil, for: .compact)
            bar.setBackgroundImage(nil, for: .defaultPrompt)
            bar.setBackgroundImage(nil, for: .compactPrompt)
            bar.titleTextAttributes = nil
            bar.largeTitleTextAttributes = nil
            bar.backIndicatorImage = nil
            bar.backIndicatorTransitionMaskImage = nil
            for metrics in [UIBarMetrics.default, .compact, .defaultPrompt, .compactPrompt] {
                bar.setTitleVerticalPositionAdjustment(0, for: metrics)
            }
        }
    }
}

extension View {
    /// Applies `NavBarAppearanceReset` to this view, resetting the navigation bar
    /// `UIAppearance` for the subhierarchy to avoid inheriting global app settings.
    func resetNavBarAppearance() -> some View {
        background(NavBarAppearanceReset().frame(width: 0, height: 0))
    }
}

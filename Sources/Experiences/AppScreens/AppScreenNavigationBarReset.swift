import SwiftUI
import UIKit

/// Clears appearance-proxy state on the bar owned by the App Screens flow.
/// These are instance assignments, matching `NavBarAppearanceReset`, so
/// they take precedence over the host application's global appearance.
///
/// `private`: this is the file-local scrub used by `NavBarAppearanceReset`
/// below. Lives in its own file so trimming the legacy App Screens code out
/// of `ExperienceViewController` cannot orphan this shared helper.
private func resetAppScreensNavigationBar(_ bar: UINavigationBar) {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()

    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactAppearance = appearance
    bar.compactScrollEdgeAppearance = appearance

    bar.tintColor = nil
    bar.isTranslucent = true
    bar.backgroundColor = nil
    bar.barStyle = .default
    bar.prefersLargeTitles = false
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

/// Resets the navigation bar `UIAppearance` for this subhierarchy, avoiding
/// inheriting global app appearance settings.
package struct NavBarAppearanceReset: UIViewControllerRepresentable {
    /// How the enclosing screen's navigation bar should render once shielded from
    /// the host app's global appearance settings.
    package enum Style {
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

    package func makeUIViewController(context: Context) -> Controller { Controller(style: style) }
    package func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    package final class Controller: UIViewController {
        private let style: Style

        init(style: Style) {
            self.style = style
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        package override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navigationController else {
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
    package func resetNavBarAppearance(_ style: NavBarAppearanceReset.Style = .transparent) -> some View {
        background(NavBarAppearanceReset(style: style).frame(width: 0, height: 0))
    }
}

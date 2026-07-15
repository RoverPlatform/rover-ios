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
import RoverUI
import UIKit
import os.log

/// The `RoverViewController` fetches experiences from Rover's server and displays a loading screen while it is loading.
/// The loading screen can be customized by overriding the `loadingViewController()` method and supplying your own. The
/// Rover SDK comes with a default loading screen `LoadingViewController` which you can override and customize to suit
/// your needs. You can also supply your own view controller.
open class ExperienceViewController: UIViewController {
    #if swift(>=4.2)
        override open var childForStatusBarStyle: UIViewController? {
            return self.children.first
        }
    #else
        override open var childViewControllerForStatusBarStyle: UIViewController? {
            return self.childViewControllers.first
        }
    #endif

    private var url: URL?
    private var experienceStore: ExperienceStore = Rover.shared.resolve(ExperienceStore.self)!

    /// The App Screens flow's root host, stashed by `loadAppScreensExperience` so
    /// `popAppScreensNavigationToRoot` can pop the child navigation stack back to it
    /// on a Hub-driven reset, and so the root bar item / close button can be
    /// installed on it. `nil` for non-App-Screens experiences.
    private weak var appScreensRootHost: UIViewController?

    /// An optional dismissal closure supplied by a presenter that owns this
    /// experience's full-screen, dismissable presentation. When non-`nil`, an xmark
    /// close item is installed on the App Screens ROOT host at load time and its
    /// action invokes this closure — the closure body performs the dismissal
    /// (e.g. `dismiss(animated:)` from the actual presenter). Leave `nil` when
    /// embedding the experience (e.g. inside a developer's own sheet or the Hub), so
    /// no close chrome is added. Set before `loadExperience`, mirroring the
    /// `setAppScreensRootBarItem(_:)` host-configuration pattern. By convention a host
    /// supplies either this handler or `appScreensRootBarItem`, never both.
    var onDismissButtonPressed: (() -> Void)?

    /// An optional URL-opening override consulted only for the `openURL` bridge
    /// message from a V3 App Screens experience (never for the in-app
    /// `presentWebsite`, and not for V1/V2 experiences). Threaded to the navigator's
    /// root session at load time; when `nil` the URL is handed to the OS via
    /// `UIApplication.shared.open`. Set before `loadExperience`, mirroring
    /// `onDismissButtonPressed`.
    var onOpenURL: ((URL) -> Void)?

    /// An optional native item the embedding host (e.g. the Hub) wants installed on
    /// the App Screens ROOT host's `navigationItem.rightBarButtonItem` — the inbox
    /// affordance for a V3 home view. Set via `setAppScreensRootBarItem(_:)` before
    /// (or after) load; installed on the root host as soon as it exists, and
    /// reinstalled in place when the item changes (e.g. a live badge-count update).
    /// `nil` for the modal/UIKit entry point, which uses the xmark close item
    /// instead. The two never coexist: the modal entry supplies no root bar item and
    /// the Hub embed is never presented modally.
    private var appScreensRootBarItem: AppScreensRootBarItem?

    deinit {
        // This view controller owns the App Screens presentation. When it goes away
        // (the modal is dismissed, or a Hub-owned controller is removed), release the
        // navigator's root session so its web view is reclaimed — or demoted to the
        // warm pool — rather than leaking on-stack in the navigator singleton forever.
        // The navigator's `onPopped` teardown never fires for a root dismissed with
        // its containing navigation controller, so this is the root's teardown seat.
        // No-op / idempotent for a non-App-Screens experience (no root host) or after
        // an earlier release. `resolve` is optional-guarded so a container torn down
        // before this VC can never crash `deinit`.
        //
        // A `UIViewController` deallocates on the main thread, so the main-actor
        // navigator is safe to touch here; `assumeIsolated` bridges the nonisolated
        // `deinit` to it (mirroring the navigator's own main-thread WebKit callbacks).
        MainActor.assumeIsolated {
            if let rootHost = appScreensRootHost,
                let navigator = Rover.shared.resolve(AppScreensNavigator.self)
            {
                navigator.releaseRootPresentation(rootHost)
            }
        }
    }
    
    /// The App Screens navigation controller is nested inside this controller,
    /// so a reset applied to the outer SwiftUI navigation stack cannot clear the
    /// host application's `UINavigationBar.appearance()` values from it.
    private var appScreensNavigationController: UINavigationController? {
        appScreensRootHost?.navigationController
    }

    /// Load a Rover experience into a newly instantiated ExperienceViewController.
    /// This URL can be:
    ///  * a file URL
    ///  * an HTTP URL
    ///  * a deeplink
    ///  * a universal link
    ///
    /// - Parameter url: The URL  associated with the experience to load.
    public static func openExperience(with experienceUrl: URL) -> ExperienceViewController {
        let experienceViewController = ExperienceViewController()
        experienceViewController.loadExperience(with: experienceUrl)
        return experienceViewController
    }

    /// Load a Rover experience into the view controller referenced by its URL.
    /// This can be:
    ///  * a file URL
    ///  * an HTTP URL
    ///  * a deeplink
    ///  * a universal link
    ///
    /// - Parameter url: The URL  associated with the experience to load.
    public func loadExperience(with url: URL) {
        self.url = url
        loadExperience()
    }

    private func loadExperience() {
        guard let url = url else {
            return
        }

        // V3 App Screens (`/a/` paths) never reach the experience store — the
        // host view controller owns its own loading/reveal. Branch before the
        // store (and before the LoadingViewController). All other URLs keep
        // their existing behavior untouched.
        if ExperienceURLClassifier.classify(url) == .appScreens {
            loadAppScreensExperience(with: url)
            return
        }

        let loadingViewController = self.loadingViewController()
        setChildViewController(loadingViewController)

        experienceStore.fetchExperience(for: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }

                switch result {
                case .failure(let error):
                    os_log(
                        "Unable to load experience (from url %s) due to: %s",
                        log: .experiences,
                        type: .error,
                        url.toString(),
                        error.debugDescription
                    )
                    self.showError(error: error, shouldRetry: error.isRetryable)
                case .success(let experience):
                    let viewController = self.renderViewController(experience: experience)

                    self.setChildViewController(viewController)
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }

    /// Loads a V3 App Screens experience: normalizes the scheme, gates the
    /// domain (mirroring `ExperienceStoreService`), then installs the navigator's
    /// root host inside a child `UINavigationController`.
    private func loadAppScreensExperience(with url: URL) {
        // Deep links arrive with a custom scheme; normalize to https before the
        // domain gate and the network fetch (mirrors the store's normalization).
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            showError(error: nil, shouldRetry: false)
            return
        }
        urlComponents.scheme = "https"

        guard let normalizedURL = urlComponents.url else {
            showError(error: nil, shouldRetry: false)
            return
        }

        // The workspace host must be one of the app's associated domains.
        let router = Rover.shared.resolve(Router.self)!
        guard router.isValidDomain(for: normalizedURL) else {
            os_log(
                "Refusing to load App Screens experience from unauthorized domain: %s",
                log: .appScreens,
                type: .error,
                normalizedURL.toString()
            )
            showError(error: nil, shouldRetry: false)
            return
        }

        let navigator = Rover.shared.resolve(AppScreensNavigator.self)!
        let rootHost = navigator.makeRootViewController(
            for: normalizedURL,
            onDismissButtonPressed: onDismissButtonPressed,
            onOpenURL: onOpenURL
        )

        let navigationController = UINavigationController(rootViewController: rootHost)
        resetAppScreensNavigationBar(navigationController.navigationBar)

        // Stash the root host so `popAppScreensNavigationToRoot` can pop the child
        // navigation stack back to it on a Hub-driven reset.
        appScreensRootHost = rootHost

        // Install the host-supplied root bar item (the Hub inbox affordance) on the
        // root host only, so pushing a detail hides it and popping restores it. Runs
        // before the close-button install so, in the (by-convention-impossible) event
        // both were supplied, the root bar item's `nil`-clear can't clobber the close
        // button.
        installAppScreensRootBarItem(on: rootHost)

        // A presenter that declared this experience dismissable (by supplying
        // `onDismissButtonPressed`) gets an xmark close affordance on the ROOT host
        // only — pushed pages show the child nav's back button, and App Screens sheets
        // keep their own close chrome. Embedded experiences leave the handler `nil`
        // and get no close chrome.
        installAppScreensCloseButton(on: rootHost)

        setChildViewController(navigationController)
        setNeedsStatusBarAppearanceUpdate()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController = appScreensNavigationController {
            resetAppScreensNavigationBar(navigationController.navigationBar)
        }
    }

    /// Sets (or clears/updates) the native root bar item for the App Screens flow.
    /// Stores it, and — if the root host already exists — (re)installs it in place so
    /// a changed badge count propagates. Called by the SwiftUI `ExperienceView`
    /// bridge on make and on every update; skips the reinstall when nothing visible
    /// changed so an unchanged SwiftUI re-render doesn't churn the bar button.
    func setAppScreensRootBarItem(_ item: AppScreensRootBarItem?) {
        let unchanged =
            item?.systemImageName == appScreensRootBarItem?.systemImageName
            && item?.badgeText == appScreensRootBarItem?.badgeText
            && item?.accessibilityLabel == appScreensRootBarItem?.accessibilityLabel
            && item?.accessibilityIdentifier == appScreensRootBarItem?.accessibilityIdentifier
            && (item == nil) == (appScreensRootBarItem == nil)
        appScreensRootBarItem = item

        guard let rootHost = appScreensRootHost, !unchanged else {
            return
        }
        installAppScreensRootBarItem(on: rootHost)
    }

    /// Builds a standard image `UIBarButtonItem` (rendered as liquid glass by the
    /// iOS 26 navigation bar) from the stored root bar item and installs it on the
    /// root host. A custom-view bar item would NOT receive the automatic shared
    /// glass background, so this uses a plain image item plus the native
    /// `UIBarButtonItem.badge` (iOS 26+) for the unread count. No-op-safe: clears the
    /// item when none is set.
    private func installAppScreensRootBarItem(on rootHost: UIViewController) {
        guard let item = appScreensRootBarItem else {
            rootHost.navigationItem.rightBarButtonItem = nil
            return
        }

        let barButtonItem = UIBarButtonItem(
            image: UIImage(systemName: item.systemImageName),
            primaryAction: UIAction { _ in item.action() }
        )
        barButtonItem.accessibilityLabel = item.accessibilityLabel
        barButtonItem.accessibilityIdentifier = item.accessibilityIdentifier

        if #available(iOS 26.0, *) {
            barButtonItem.badge = Self.makeBadge(from: item.badgeText)
        }

        rootHost.navigationItem.rightBarButtonItem = barButtonItem
    }

    /// Maps the host's badge string to a native `UIBarButtonItem.Badge`: a numeric
    /// string becomes a count badge, any other non-empty string a text badge, and
    /// `nil`/empty clears it.
    @available(iOS 26.0, *)
    private static func makeBadge(from text: String?) -> UIBarButtonItem.Badge? {
        guard let text, !text.isEmpty else {
            return nil
        }
        if let count = Int(text) {
            return .count(count)
        }
        return .string(text)
    }

    /// Pops the App Screens child navigation stack back to its root host (and
    /// dismisses any App Screens sheets), releasing every pushed session exactly as
    /// a normal pop would. Invoked by the SwiftUI `ExperienceView` bridge when the
    /// Hub performs a coordinator-driven navigation reset, so backing out never
    /// reveals a stale pushed detail. No-op for a non-App-Screens experience or
    /// before the flow has loaded (no root host / navigation controller yet).
    func popAppScreensNavigationToRoot() {
        guard
            let rootHost = appScreensRootHost,
            let navigationController = rootHost.navigationController
        else {
            return
        }

        let navigator = Rover.shared.resolve(AppScreensNavigator.self)!
        navigator.popToRoot(in: navigationController)
    }

    /// Installs the xmark close item on the App Screens root host when a presenter
    /// supplied `onDismissButtonPressed`; the item's action invokes that handler,
    /// whose body performs the dismissal. No-op when the handler is `nil` (the
    /// embedded case), leaving the root host's bar untouched. Uses target/action
    /// (rather than a `UIAction` closure) so the wiring is exercisable in a headless
    /// unit test. `internal` for that test seam.
    func installAppScreensCloseButton(on rootHost: UIViewController) {
        guard onDismissButtonPressed != nil else {
            return
        }

        rootHost.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(appScreensCloseButtonTapped)
        )
    }

    @objc private func appScreensCloseButtonTapped() {
        onDismissButtonPressed?()
    }

    #if swift(>=4.2)
        private func setChildViewController(_ childViewController: UIViewController) {
            if let existingChildViewController = self.children.first {
                existingChildViewController.willMove(toParent: nil)
                existingChildViewController.view.removeFromSuperview()
                existingChildViewController.removeFromParent()
            }

            childViewController.willMove(toParent: self)
            addChild(childViewController)
            childViewController.view.frame = view.bounds
            view.addSubview(childViewController.view)
            childViewController.didMove(toParent: self)
        }
    #else
        private func setChildViewController(_ childViewController: UIViewController) {
            if let existingChildViewController = self.childViewControllers.first {
                existingChildViewController.willMove(toParentViewController: nil)
                existingChildViewController.view.removeFromSuperview()
                existingChildViewController.removeFromParentViewController()
            }

            childViewController.willMove(toParentViewController: self)
            addChildViewController(childViewController)
            childViewController.view.frame = view.bounds
            view.addSubview(childViewController.view)
            childViewController.didMove(toParentViewController: self)
        }
    #endif

    private func showError(error: Error?, shouldRetry: Bool) {
        if self.presentingViewController != nil {
            presentError(shouldRetry: shouldRetry)
        } else {
            embedError(shouldRetry: shouldRetry)
        }
    }

    private func embedError(shouldRetry: Bool) {
        let errorViewController = ErrorViewController(shouldRetry: shouldRetry) {
            self.loadExperience()
        }

        self.setChildViewController(errorViewController)
    }

    private func presentError(shouldRetry: Bool) {
        let alertController: UIAlertController
        if shouldRetry {
            alertController = UIAlertController(
                title: NSLocalizedString("Error", comment: "Rover Error Dialog Title"),
                message: NSLocalizedString(
                    "Failed to load experience",
                    comment: "Rover Failed to load experience error message"
                ),
                preferredStyle: UIAlertController.Style.alert
            )
            let cancel = UIAlertAction(
                title: NSLocalizedString("Cancel", comment: "Rover Cancel Action"),
                style: UIAlertAction.Style.cancel
            ) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
            let retry = UIAlertAction(
                title: NSLocalizedString("Try Again", comment: "Rover Try Again Action"),
                style: UIAlertAction.Style.default
            ) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.loadExperience()
            }

            alertController.addAction(cancel)
            alertController.addAction(retry)
        } else {
            alertController = UIAlertController(
                title: NSLocalizedString("Error", comment: "Rover Error Title"),
                message: NSLocalizedString("Something went wrong", comment: "Rover Something Went Wrong message"),
                preferredStyle: UIAlertController.Style.alert
            )

            let ok = UIAlertAction(
                title: NSLocalizedString("Ok", comment: "Rover Ok Action"),
                style: UIAlertAction.Style.default
            ) { _ in
                alertController.dismiss(animated: false, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }

            alertController.addAction(ok)
        }

        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: Factories

    /// Construct a view controller to display while loading an experience from Rover's server. The default
    /// returns an instance `LoadingViewController`. You can override this method if you want to use a different view
    /// controller.
    open func loadingViewController() -> UIViewController {
        return LoadingViewController()
    }

    private func renderViewController(experience: LoadedExperience) -> UIViewController {
        switch experience {
        case .classic(let classicExperienceModel, let urlParameters):
            return RenderClassicExperienceViewController(
                experience: classicExperienceModel,
                campaignID: urlParameters["campaignID"],
                initialScreenID: urlParameters["screenID"]
            )

        case .standard(
            let experienceModel,
            let urlParameters
        ):
            let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
            return RenderExperienceViewController(
                experience: experienceModel,
                urlParameters: urlParameters,
                userInfo: experienceManager.userInfo,
                authorizers: experienceManager.authorizers
            )

        case .file(
            let experienceModel,
            let urlParameters,
            let userInfo,
            let authorizers
        ):
            return RenderExperienceViewController(
                experience: experienceModel,
                urlParameters: urlParameters,
                userInfo: userInfo,
                authorizers: authorizers
            )
        }
    }
}

/// Clears appearance-proxy state on the bar owned by the App Screens flow.
/// These are instance assignments, matching `NavBarAppearanceReset`, so
/// they take precedence over the host application's global appearance.
package func resetAppScreensNavigationBar(_ bar: UINavigationBar) {
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

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
    /// embedding the experience (e.g. inside a developer's own sheet or an embedded
    /// Hub), so no close chrome is added. Set before `loadExperience`, mirroring the
    /// `setAppScreensRootBarItem(_:)` host-configuration pattern.
    ///
    /// This and `appScreensRootBarItem` can coexist (a *presented* Hub whose home view
    /// enables the inbox). When both are set, `installAppScreensRootBarButtons(on:)`
    /// places the close item on the LEADING edge and the inbox on the TRAILING edge so
    /// neither is lost; a standalone close item (no inbox) stays on the trailing edge.
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
    /// Takes the trailing slot; when a close item is also present it moves to the
    /// leading edge so both coexist (see `onDismissButtonPressed`).
    private var appScreensRootBarItem: AppScreensRootBarItem?

    /// Whether the App Screens root bar buttons (inbox and modal close) render the
    /// V2 "compatibility" chrome — a `.thinMaterial` circle behind the glyph,
    /// matching the SwiftUI Hub's `CompatibleInboxToolbarButton` — instead of relying on
    /// the iOS 26 navigation bar's native liquid-glass bar items. Seeded from the
    /// process gate `toolbarItemsRequireCompatibilityChrome` (the plist flag
    /// or a pre-iOS-26 OS) but stored so unit tests can force either branch
    /// deterministically on any simulator — the gate itself is OS/plist-dependent
    /// and the suite runs on both iOS 18 and iOS 26. `internal`, not public.
    var appScreensUsesCompatibilityChrome: Bool = toolbarItemsRequireCompatibilityChrome

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

        // Install the App Screens ROOT host's bar buttons — the Hub inbox affordance
        // and/or the modal xmark close item, placed on opposite edges when both are
        // present (see `installAppScreensRootBarButtons`). Root host only, so pushing a
        // detail hides them and popping restores them. Embedded experiences supply
        // neither and get a clean bar.
        installAppScreensRootBarButtons(on: rootHost)

        setChildViewController(navigationController)
        setNeedsStatusBarAppearanceUpdate()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController = appScreensNavigationController {
            resetAppScreensNavigationBar(navigationController.navigationBar)
        }
    }

    /// Updates the App Screens dismissal handler in place. The handler is the single
    /// gate for BOTH the `openURL { dismiss: true }` teardown AND the root host's xmark
    /// close item (installed iff non-`nil`). A modally-presented Hub only learns it is
    /// presented after load (at `HubHostingController.viewWillAppear`), so the handler
    /// flips from its embedded default (`nil`) to the real dismissal then, arriving
    /// here via the same live `updateUIViewController` path the inbox badge rides — no
    /// session or web-view recreation. Propagates the new handler to the live root
    /// session (so `openURL` dismiss honors it) and, when the handler's presence
    /// changed, re-runs the root bar install (so the xmark appears/disappears). No-op
    /// before the root host exists — the initial value is read straight from the
    /// property when `loadAppScreensExperience` creates the root.
    func setOnDismissButtonPressed(_ handler: (() -> Void)?) {
        let presenceChanged = (onDismissButtonPressed != nil) != (handler != nil)
        onDismissButtonPressed = handler

        guard let rootHost = appScreensRootHost else {
            return
        }
        // Keep the live root session's openURL-dismiss in sync with the button.
        let navigator = Rover.shared.resolve(AppScreensNavigator.self)!
        navigator.setRootDismissHandler(for: rootHost, onDismissButtonPressed: handler)

        // Only the button's presence (not the closure identity) changes the bar.
        guard presenceChanged else {
            return
        }
        installAppScreensRootBarButtons(on: rootHost)
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
        installAppScreensRootBarButtons(on: rootHost)
    }

    /// Installs the App Screens ROOT host's bar buttons — the host's inbox affordance
    /// (`appScreensRootBarItem`) and/or the modal xmark close item (when
    /// `onDismissButtonPressed` is set) — resolving their placement:
    ///
    /// - both present (a *presented* Hub whose home view enables the inbox) → close on
    ///   the LEADING edge, inbox on the TRAILING edge, so neither is lost;
    /// - exactly one present → it takes the trailing slot, leading stays clear;
    /// - neither → both slots cleared.
    ///
    /// So a standalone dismissable experience keeps its close item on the trailing
    /// edge (where it ships), and the close item only moves to the leading edge when
    /// the inbox would otherwise collide with it. Called at load and on every
    /// root-bar-item update (badge change or a config-driven inbox toggle); because it
    /// recomputes BOTH slots every call, a dynamic inbox appearing/disappearing slides
    /// the close item between edges and never strands a stale button. Root host only,
    /// whose leading slot is free (the root has no system back button). `internal` so
    /// the target/action close wiring is exercisable in a headless unit test.
    func installAppScreensRootBarButtons(on rootHost: UIViewController) {
        let inbox = appScreensRootBarItem.map(makeInboxBarButtonItem)
        let close = onDismissButtonPressed != nil ? makeCloseBarButtonItem() : nil

        if inbox != nil, close != nil {
            rootHost.navigationItem.leftBarButtonItem = close
            rootHost.navigationItem.rightBarButtonItem = inbox
        } else {
            rootHost.navigationItem.leftBarButtonItem = nil
            rootHost.navigationItem.rightBarButtonItem = inbox ?? close
        }
    }

    /// Builds the host's inbox affordance bar button. The path splits on the
    /// compatibility seam (`appScreensUsesCompatibilityChrome`), not the OS, so an
    /// iOS 26 app with `UIDesignRequiresCompatibility` also gets the custom chrome
    /// (matching the SwiftUI Hub's `CompatibleInboxToolbarButton`):
    ///
    /// - **Gate OFF** (iOS 26 native chrome): a plain image `UIBarButtonItem` plus
    ///   the native `UIBarButtonItem.badge`. A custom-view bar item would NOT receive
    ///   the automatic shared glass background, so the item must stay a
    ///   NON-custom-view image item here to keep the liquid-glass rendering. The
    ///   badge API is iOS 26-only; the `#available` guard keeps it compiling and
    ///   applies it only where it exists (gate-off implies iOS 26 in practice).
    /// - **Gate ON** (compatibility chrome): a `UIBarButtonItem(customView:)`
    ///   wrapping a `UIButton` inside a `.thinMaterial` circle with a hand-drawn
    ///   unread badge overlay (see `makeLegacyInboxView`).
    private func makeInboxBarButtonItem(_ item: AppScreensRootBarItem) -> UIBarButtonItem {
        guard appScreensUsesCompatibilityChrome else {
            let barButtonItem = UIBarButtonItem(
                image: UIImage(systemName: item.systemImageName),
                primaryAction: UIAction { _ in item.action() }
            )
            barButtonItem.accessibilityLabel = item.accessibilityLabel
            barButtonItem.accessibilityIdentifier = item.accessibilityIdentifier
            if #available(iOS 26.0, *) {
                barButtonItem.badge = Self.makeBadge(from: item.badgeText)
            }
            return barButtonItem
        }

        let barButtonItem = UIBarButtonItem(customView: Self.makeLegacyInboxView(item))
        // The inner button carries these too (so the accessible `.button` element the
        // E2E matches on has them); mirroring them on the bar item keeps the install
        // logic identifiable by tests and tools inspecting the bar item directly.
        barButtonItem.accessibilityLabel = item.accessibilityLabel
        barButtonItem.accessibilityIdentifier = item.accessibilityIdentifier
        return barButtonItem
    }

    /// Builds the compatibility-chrome inbox custom view: a `UIButton` glyph inside a
    /// 40×40 `.thinMaterial` circle (matching the SwiftUI Hub's
    /// `CompatibleInboxToolbarButton`) with a hand-drawn unread badge overlaid on the
    /// circle's top-trailing rim (parity with the native `UIBarButtonItem.badge` the
    /// iOS 26 path gets for free). Extracted as an `internal static` seam — with no
    /// runtime `#available` gate — so a headless unit test can exercise the
    /// compatibility branch even when the test suite runs on an iOS 26 simulator.
    ///
    /// The circle is unconditional here: this helper is only reached when the
    /// compatibility seam is on. The button carries the item's
    /// `accessibilityLabel`/`accessibilityIdentifier` (so `app.buttons["rover.hub.inbox"]`
    /// in the E2E tests keeps matching) and, when a badge is shown, its
    /// `accessibilityValue` mirrors the badge text (VoiceOver parity with the native
    /// badge). `nil`/empty `badgeText` renders no badge label.
    static func makeLegacyInboxView(_ item: AppScreensRootBarItem) -> UIView {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item.systemImageName), for: .normal)
        button.addAction(UIAction { _ in item.action() }, for: .touchUpInside)
        button.accessibilityLabel = item.accessibilityLabel
        button.accessibilityIdentifier = item.accessibilityIdentifier

        let container = makeCompatibilityCircleContainer(around: button)

        guard let badgeText = item.badgeText, !badgeText.isEmpty else {
            return container
        }

        button.accessibilityValue = badgeText

        // The badge is added last so it stays top-most in z-order, above the circle
        // and glyph, and is placed on the circle's top-trailing rim so it reads like
        // the system badge on the iOS 26 glass capsule. No vertical offset on the
        // circle itself — everything fits the 44pt bar.
        let badge = InboxBadgeLabel(text: badgeText)
        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: 14),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -14)
        ])
        return container
    }

    /// Wraps `button` in the shared V2 compatibility chrome: a 40×40 circular
    /// `.thinMaterial` background with a drop shadow behind the glyph, tinted
    /// `.label` — the UIKit equivalent of `CompatibleInboxToolbarButton`'s
    /// `Circle().fill(.thinMaterial).shadow(radius: 5)` + `.tint(.primary)`. Returns
    /// the outer container to use as a bar item's `customView`.
    ///
    /// The shadow lives on its own non-clipping wrapper because a layer that clips
    /// (the material circle must, to round its corners) cannot also cast a shadow.
    /// The effect view and shadow wrapper are non-interactive so taps reach the
    /// button; the button is centered above them with a ≥40pt tap target. Dark mode
    /// adapts automatically via `.systemThinMaterial` + `.label`.
    private static func makeCompatibilityCircleContainer(around button: UIButton) -> UIView {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .label

        let container = UIView()

        let shadowWrapper = UIView()
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
        shadowWrapper.isUserInteractionEnabled = false
        shadowWrapper.layer.shadowColor = UIColor.black.cgColor
        shadowWrapper.layer.shadowOpacity = 0.33
        shadowWrapper.layer.shadowRadius = 5
        shadowWrapper.layer.shadowOffset = .zero

        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.isUserInteractionEnabled = false
        effectView.layer.cornerRadius = 20
        effectView.clipsToBounds = true

        shadowWrapper.addSubview(effectView)
        container.addSubview(shadowWrapper)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            shadowWrapper.widthAnchor.constraint(equalToConstant: 40),
            shadowWrapper.heightAnchor.constraint(equalToConstant: 40),
            shadowWrapper.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            shadowWrapper.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            effectView.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor),

            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])

        return container
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

    /// Builds the xmark close item whose action invokes `onDismissButtonPressed`
    /// (the closure body performs the dismissal). Uses target/action (rather than a
    /// `UIAction` closure) so the wiring is exercisable in a headless unit test.
    ///
    /// The path splits on the compatibility seam:
    ///
    /// - **Gate OFF** (iOS 26 native chrome): a plain image `UIBarButtonItem`, drawn
    ///   as liquid glass by the navigation bar. The system exposes its accessibility
    ///   label ("Close") for free.
    /// - **Gate ON** (compatibility chrome): a `UIBarButtonItem(customView:)`
    ///   wrapping a `UIButton` inside the same 40×40 `.thinMaterial` circle used by
    ///   the inbox glyph. The inner button is wired to the same
    ///   `appScreensCloseButtonTapped` target/action seam so the close still fires
    ///   `onDismissButtonPressed`, and the "Close" accessibility label (which the
    ///   native item provides automatically) is set explicitly on both the button
    ///   and the bar item so `app.buttons["Close"]` and VoiceOver keep matching.
    private func makeCloseBarButtonItem() -> UIBarButtonItem {
        guard appScreensUsesCompatibilityChrome else {
            return UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(appScreensCloseButtonTapped)
            )
        }

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.addTarget(self, action: #selector(appScreensCloseButtonTapped), for: .touchUpInside)
        button.accessibilityLabel = Self.closeButtonAccessibilityLabel

        let barButtonItem = UIBarButtonItem(customView: Self.makeCompatibilityCircleContainer(around: button))
        barButtonItem.accessibilityLabel = Self.closeButtonAccessibilityLabel
        return barButtonItem
    }

    /// The accessibility label for the compatibility custom-view close button, where
    /// the system does not supply one automatically (the native `UIBarButtonItem(image:)`
    /// path gets an OS-localized "Close" from the SF Symbol for free). Routed through
    /// `NSLocalizedString` with the same `"Close"` key and `"Rover Close"` comment the
    /// Classic experiences close button uses (`ClassicScreenViewController`) and matching
    /// the sibling inbox label's `NSLocalizedString("Inbox", ...)` convention, so this is
    /// a real localization extraction point rather than hard-coded English. Resolves to
    /// "Close" in English, so the E2E `app.buttons["Close"]` matcher and VoiceOver keep
    /// matching on both the native and compatibility paths.
    private static let closeButtonAccessibilityLabel = NSLocalizedString(
        "Close",
        comment: "Rover Close"
    )

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

/// A pill-shaped unread badge for the pre-iOS-26 inbox bar button: white bold
/// ~11pt text on a `.systemRed` capsule. Circular for a single character (min
/// 16pt), widening to a capsule with ~4pt horizontal padding for longer text
/// (numeric counts or text badges like `"99+"`). `isUserInteractionEnabled` is
/// off so it never eats taps meant for the underlying button.
private final class InboxBadgeLabel: UILabel {
    private let horizontalPadding: CGFloat = 4
    private let minimumSize: CGFloat = 16

    init(text: String) {
        super.init(frame: .zero)
        self.text = text
        font = .systemFont(ofSize: 11, weight: .bold)
        textColor = .white
        textAlignment = .center
        numberOfLines = 1
        backgroundColor = .systemRed
        clipsToBounds = true
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        let height = max(minimumSize, base.height)
        // Circular for a single digit (width == height); capsule once the padded
        // text is wider than that.
        let width = max(height, base.width + horizontalPadding * 2)
        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
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

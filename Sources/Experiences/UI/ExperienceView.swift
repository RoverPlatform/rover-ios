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

/// Embeds an experience loaded from the given URL within a custom external navigation flow.
///
/// Loading is triggered on appear and when the URL changes, and the same URL is not
/// reloaded. When presented modally, errors are surfaced via an alert; otherwise the
/// inline error view is shown.
///
/// - Note: This view is used exclusively by the Hub. It is not part of
///   the standard Rover Experiences rendering path used by `RoverExperiences` elsewhere in the SDK.
public struct ExperienceView: View {
    @StateObject private var state: ExperienceViewState
    @Environment(\.dismiss) private var dismiss

    let url: URL
    @Binding var path: NavigationPath
    let isPresentedModally: Bool

    /// An optional dismissal closure for a full-screen, dismissable App Screens
    /// presentation. Pass when presenting the experience full-screen and dismissable;
    /// the closure performs the dismissal (e.g. `dismiss(animated:)` from the actual
    /// presenter, such as `@Environment(\.dismiss)`). Leave unset when embedding.
    /// Threaded to the wrapped `ExperienceViewController`, which installs an xmark
    /// close item on the App Screens root host when it is non-`nil`. `nil` for the
    /// Hub embed / document path.
    private let onDismissButtonPressed: (() -> Void)?

    /// An optional URL-opening override, consulted only for the `openURL` bridge
    /// message from a V3 App Screens experience (never for the in-app
    /// `presentWebsite`, and not for V1/V2 experiences). Threaded to the wrapped
    /// `ExperienceViewController`; when `nil` the URL is handed to the OS via
    /// `UIApplication.shared.open`. `nil` for the deprecated and `package` inits.
    private let onOpenURL: ((URL) -> Void)?

    /// An optional native item to install on the App Screens ROOT screen only (the
    /// Hub inbox affordance). Ignored by the document-experience path. Threaded to
    /// the wrapped `ExperienceViewController` and kept in sync on update so badge
    /// changes propagate. `nil` for the public init.
    private let appScreensRootBarItem: AppScreensRootBarItem?

    /// The Hub's `HubCoordinator.appScreensResetGeneration`. Each increment signals
    /// the embedded App Screens flow to pop its child navigation stack to root (and
    /// dismiss any App Screens sheets), so a coordinator-driven navigation never
    /// reveals a stale pushed detail on back-out. `0` for the public init, whose
    /// callers do not embed the Hub-driven App Screens home view.
    private let appScreensResetGeneration: Int

    /// Creates an experience view for the given URL.
    ///
    /// - Parameters:
    ///   - url: The experience URL to load.
    ///   - path: The external navigation path the experience drives.
    ///   - onDismissButtonPressed: An optional dismissal closure. Pass when
    ///     presenting the experience full-screen and dismissable; the closure
    ///     performs the dismissal (e.g. `dismiss(animated:)` from the actual
    ///     presenter, such as `@Environment(\.dismiss)`). When set, a full-screen
    ///     App Screens experience shows an xmark close item on its root screen whose
    ///     action invokes this closure. Leave unset when embedding.
    ///   - onOpenURL: An optional URL-opening override, consulted only for the
    ///     `openURL` bridge message from a V3 App Screens experience (never for the
    ///     in-app `presentWebsite`, and not for V1/V2 experiences); when `nil` the URL
    ///     is handed to the OS via `UIApplication.shared.open`.
    public init(
        url: URL,
        path: Binding<NavigationPath>,
        onDismissButtonPressed: (() -> Void)? = nil,
        onOpenURL: ((URL) -> Void)? = nil
    ) {
        self.url = url
        self._state = StateObject(wrappedValue: ExperienceViewState())
        self._path = path
        self.isPresentedModally = false
        self.onDismissButtonPressed = onDismissButtonPressed
        self.onOpenURL = onOpenURL
        self.appScreensRootBarItem = nil
        self.appScreensResetGeneration = 0
    }

    /// Creates an experience view, opting into the v2 document-experience modal
    /// error-alert style.
    ///
    /// - Note: `isPresentedModally` only toggles whether a failed *document*
    ///   experience surfaces its error via an alert (modal) or an inline error view;
    ///   despite the name it does not control close chrome. Prefer
    ///   ``init(url:path:onDismissButtonPressed:)`` and supply a dismissal closure to
    ///   present a dismissable full-screen experience.
    @available(
        *,
        deprecated,
        message:
            "isPresentedModally only gates the v2 document error-alert style, not close chrome. Use init(url:path:onDismissButtonPressed:)."
    )
    public init(
        url: URL,
        path: Binding<NavigationPath>,
        isPresentedModally: Bool
    ) {
        self.url = url
        self._state = StateObject(wrappedValue: ExperienceViewState())
        self._path = path
        self.isPresentedModally = isPresentedModally
        self.onDismissButtonPressed = nil
        self.onOpenURL = nil
        self.appScreensRootBarItem = nil
        self.appScreensResetGeneration = 0
    }

    /// Additive `package` initializer (the public init is untouched) that lets the
    /// Hub supply a native root bar item for a V3 App Screens home view — the inbox
    /// affordance restored natively after the outer SwiftUI toolbar was hidden to
    /// avoid a double nav bar — and a reset generation that pops the App Screens
    /// child stack to root on a coordinator-driven navigation. No public API change.
    package init(
        url: URL,
        path: Binding<NavigationPath>,
        isPresentedModally: Bool = false,
        appScreensResetGeneration: Int = 0,
        appScreensRootBarItem: AppScreensRootBarItem?
    ) {
        self.url = url
        self._state = StateObject(wrappedValue: ExperienceViewState())
        self._path = path
        self.isPresentedModally = isPresentedModally
        self.onDismissButtonPressed = nil
        self.onOpenURL = nil
        self.appScreensRootBarItem = appScreensRootBarItem
        self.appScreensResetGeneration = appScreensResetGeneration
    }

    public var body: some View {
        if ExperienceURLClassifier.classify(url) == .appScreens {
            // V3 App Screens gets one construction path: wrap the UIKit
            // ExperienceViewController (which owns the child nav + skeleton) and
            // hide the outer SwiftUI toolbar so there is no double nav bar.
            AppScreensExperienceRepresentable(
                url: url,
                rootBarItem: appScreensRootBarItem,
                resetGeneration: appScreensResetGeneration,
                onDismissButtonPressed: onDismissButtonPressed,
                onOpenURL: onOpenURL
            )
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
        } else {
            documentExperienceBody
        }
    }

    private var documentExperienceBody: some View {
        SwiftUI.ZStack {
            switch state.loadingState {
            case .loading:
                ExperienceLoadingView()
            case .error(let error, let isRetryable):
                if isPresentedModally {
                    Color.clear
                        .onAppear {
                            state.showErrorAlertIfNeeded(isRetryable: isRetryable)
                        }
                } else {
                    ExperienceErrorView(
                        error: error,
                        shouldRetry: isRetryable,
                        retryHandler: {
                            state.loadExperience(url: url)
                        }
                    )
                }
            case .loaded(let experienceState):
                RenderExperienceView(
                    experience: experienceState.experience,
                    urlParameters: experienceState.urlParameters,
                    userInfo: experienceState.userInfo,
                    authorizers: experienceState.authorizers,
                    path: $path
                )
            }
        }
        .onAppear {
            state.loadExperience(url: url)
        }
        .onChange(of: url) { _, newURL in
            state.loadExperience(url: newURL)
        }
        .alert("Error", isPresented: $state.showErrorAlert, presenting: state.errorAlertConfig) { config in
            if config.isRetryable {
                Button("Cancel") {
                    dismiss()
                }
                Button("Try Again") {
                    state.loadExperience(url: url)
                }
            } else {
                Button("OK") {
                    dismiss()
                }
            }
        } message: { config in
            SwiftUI.Text(config.message)
        }
    }
}

/// Wraps the UIKit `ExperienceViewController` so V3 App Screens can render inside
/// `ExperienceView` (SwiftUI). The controller owns the child navigation controller,
/// skeleton, and reveal; this representable only bridges the URL in and reloads
/// when it changes.
private struct AppScreensExperienceRepresentable: UIViewControllerRepresentable {
    let url: URL
    let rootBarItem: AppScreensRootBarItem?
    /// The Hub's reset generation. Each new value pops the App Screens child stack
    /// to root; see `ExperienceView.appScreensResetGeneration`.
    let resetGeneration: Int
    /// Forwarded to `ExperienceViewController.onDismissButtonPressed`; installs the
    /// xmark close item on the App Screens root host when non-`nil`. See
    /// `ExperienceView.onDismissButtonPressed`.
    let onDismissButtonPressed: (() -> Void)?
    /// Forwarded to `ExperienceViewController.onOpenURL`; consulted only for the
    /// `openURL` bridge message. See `ExperienceView.onOpenURL`.
    let onOpenURL: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        // Seed with the current generation so the first render never fires a pop.
        Coordinator(url: url, lastResetGeneration: resetGeneration)
    }

    func makeUIViewController(context: Context) -> ExperienceViewController {
        let viewController = ExperienceViewController()
        // Set the root bar item and dismissal handler before loading so both are
        // installed on the root host the moment `loadExperience` creates it.
        viewController.setAppScreensRootBarItem(rootBarItem)
        viewController.onDismissButtonPressed = onDismissButtonPressed
        viewController.onOpenURL = onOpenURL
        viewController.loadExperience(with: url)
        return viewController
    }

    func updateUIViewController(_ uiViewController: ExperienceViewController, context: Context) {
        // Propagate a changed root bar item (e.g. a live badge-count update) in
        // place; the setter no-ops when nothing visible changed.
        uiViewController.setAppScreensRootBarItem(rootBarItem)

        // A bumped reset generation means the Hub performed a coordinator-driven
        // navigation reset: pop the App Screens child stack to root (and dismiss any
        // App Screens sheets) so backing out never reveals a stale pushed detail.
        // Runs before the URL-change reload so a reset that coincides with a URL
        // change still releases the old stack's sessions.
        if context.coordinator.lastResetGeneration != resetGeneration {
            context.coordinator.lastResetGeneration = resetGeneration
            uiViewController.popAppScreensNavigationToRoot()
        }

        // Only reload when the URL actually changed.
        guard context.coordinator.url != url else {
            return
        }
        context.coordinator.url = url
        uiViewController.loadExperience(with: url)
    }

    final class Coordinator {
        var url: URL
        var lastResetGeneration: Int

        init(url: URL, lastResetGeneration: Int) {
            self.url = url
            self.lastResetGeneration = lastResetGeneration
        }
    }
}

/// View model backing `ExperienceView`.
///
/// Tracks loading and error state, coordinates initial fetches, and revalidates
/// experiences when the same URL is shown again.
private class ExperienceViewState: ObservableObject {
    @Published private(set) var loadingState: LoadingState = .loading
    @Published var showErrorAlert = false
    @Published private(set) var errorAlertConfig: ExperienceErrorAlertConfig?

    private var currentURL: URL?
    private let experienceStore: ExperienceStore

    init() {
        self.experienceStore = Rover.shared.resolve(ExperienceStore.self)!
    }

    /// Loads or revalidates an experience for the given URL.
    ///
    /// Revalidates when the URL matches the currently loaded experience; otherwise
    /// resets state and fetches a fresh experience.
    func loadExperience(url: URL) {
        if case .loaded = loadingState, currentURL == url {
            revalidateExperience(for: url)
            return
        }

        loadingState = .loading
        showErrorAlert = false
        currentURL = url
        fetchExperience(for: url)
    }

    /// Configures the error alert for modal presentations.
    ///
    /// Sets the alert message and retryability based on the error state.
    func showErrorAlertIfNeeded(isRetryable: Bool) {
        errorAlertConfig = ExperienceErrorAlertConfig(
            message: isRetryable
                ? NSLocalizedString(
                    "Failed to load experience",
                    comment: "Rover Failed to load experience error message"
                )
                : NSLocalizedString("Something went wrong", comment: "Rover Something Went Wrong message"),
            isRetryable: isRetryable
        )
        showErrorAlert = true
    }

    /// Fetches an experience from the store and updates loading state.
    ///
    /// Maps store results into `LoadingState` and reports unsupported classic
    /// experiences as errors.
    private func fetchExperience(for url: URL) {
        experienceStore.fetchExperience(for: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    os_log(
                        "Unable to load experience (from url %s) due to: %s",
                        log: .experiences,
                        type: .error,
                        url.toString(),
                        error.debugDescription
                    )
                    let isRetryable = error.isRetryable
                    self.loadingState = .error(error, isRetryable: isRetryable)

                case .success(let experience):
                    switch experience {
                    case .classic:
                        os_log("Classic experiences are not supported", log: .experiences, type: .error)
                        let error = NSError(
                            domain: "RoverExperiences",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Classic experiences are not supported"]
                        )
                        self.loadingState = .error(error, isRetryable: false)

                    case .standard(experience: let experienceModel, urlParameters: let urlParams):
                        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
                        let state = ExperienceState(
                            experience: experienceModel,
                            urlParameters: urlParams,
                            userInfo: experienceManager.userInfo,
                            authorizers: experienceManager.authorizers
                        )
                        self.loadingState = .loaded(state)

                    case .file(
                        experience: let experienceModel,
                        urlParameters: let urlParams,
                        let userInfo,
                        let authorizers
                    ):
                        let state = ExperienceState(
                            experience: experienceModel,
                            urlParameters: urlParams,
                            userInfo: userInfo,
                            authorizers: authorizers
                        )
                        self.loadingState = .loaded(state)
                    }
                }
            }
        }
    }

    /// Revalidates the currently loaded experience against the cached fingerprint.
    ///
    /// Updates the loaded state only when content changes and suppresses errors to
    /// avoid interrupting a loaded experience.
    private func revalidateExperience(for url: URL) {
        let revalidatingURL = url
        experienceStore.revalidateExperience(for: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                // Verify the URL still matches the currently-displayed experience.
                // If the user navigated to a different URL while revalidation was in progress,
                // discard these results to avoid overwriting state for the new URL.
                guard revalidatingURL == self.currentURL else {
                    os_log(
                        .debug,
                        log: .experiences,
                        "Revalidation result for stale URL ignored (expected %s, got %s).",
                        self.currentURL?.absoluteString ?? "nil",
                        revalidatingURL.absoluteString
                    )
                    return
                }

                switch result {
                case .unchanged:
                    os_log(.debug, log: .experiences, "No changes to current experience.")
                    break
                case .updated(let experience):
                    os_log(.debug, log: .experiences, "Current experience has changes so update.")
                    switch experience {
                    case .classic:
                        // Classic experiences are not supported
                        break
                    case .standard(let experienceModel, let urlParams):
                        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
                        self.loadingState = .loaded(
                            ExperienceState(
                                experience: experienceModel,
                                urlParameters: urlParams,
                                userInfo: experienceManager.userInfo,
                                authorizers: experienceManager.authorizers
                            )
                        )
                    case .file:
                        // File experiences are not supported as we wouldn't be downloading them from the server
                        break
                    }
                case .failure(let error):
                    // This is a silent failure - we don't want to show an error to the user
                    // They already have an experience.
                    os_log(
                        "Unable to revalidate experience (from url %s) due to: %s",
                        log: .experiences,
                        type: .error,
                        url.toString(),
                        error.debugDescription
                    )
                }
            }
        }
    }
}

private struct ExperienceErrorView: View {
    let error: Error
    let shouldRetry: Bool
    let retryHandler: () -> Void

    var body: some View {
        SwiftUI.VStack(spacing: 16) {
            SwiftUI.Text(
                NSLocalizedString("Something went wrong", comment: "Rover Failed to load experience error message")
            )
            .font(.headline)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)

            if shouldRetry {
                SwiftUI.Button(NSLocalizedString("Try Again", comment: "Rover Try Again Action")) {
                    retryHandler()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwiftUI.Color(uiColor: .systemBackground))
    }
}

private struct ExperienceLoadingView: View {
    var body: some View {
        SwiftUI.VStack(spacing: 8) {
            SwiftUI.ProgressView()
                .progressViewStyle(SwiftUI.CircularProgressViewStyle(tint: .gray))
                .scaleEffect(1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwiftUI.Color(uiColor: .systemBackground))
    }
}

private enum LoadingState: Equatable {
    case loading
    case error(Error, isRetryable: Bool)
    case loaded(ExperienceState)

    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.error, .error):
            // Just going to assume that errors are different
            return false
        case (.loaded(let lhsState), .loaded(let rhsState)):
            return lhsState == rhsState
        default:
            return false
        }
    }
}

private struct ExperienceState: Equatable {
    let experience: ExperienceModel
    let urlParameters: [String: String]
    let userInfo: [String: Any]
    let authorizers: Authorizers

    static func == (lhs: ExperienceState, rhs: ExperienceState) -> Bool {
        lhs.experience.id == rhs.experience.id
    }
}

private struct ExperienceErrorAlertConfig {
    let message: String
    let isRetryable: Bool
}

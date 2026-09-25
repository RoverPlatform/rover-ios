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
import SwiftUI
import UIKit
import os.log

/// Owns one App Screens flow's identity (`AppScreensToken`) and its throwaway
/// `AppScreensContentView` registry, so both survive SwiftUI's value-view
/// re-creation of `AppScreensHostView` across body re-evaluations. Held as a
/// `@StateObject` by `AppScreensHostView`.
///
/// The box's `deinit` is the ONLY release trigger for the flow it owns — it fires on
/// true removal of the hosting view (the Hub dismissed, Home disabled, a standalone
/// flow dismissed) or on `.id(url)`-driven recreation for a new home URL, but NOT on
/// mere occlusion (e.g. the inbox pushed over the App Screens root, which keeps the
/// hosting view alive). There is deliberately no `.onDisappear` release: that would
/// fire on occlusion too and tear down a flow the user can still navigate back to.
@MainActor
final class AppScreensTokenBox: ObservableObject {
    let token: AppScreensToken

    /// A throwaway registry: it only exists to satisfy `AppScreensContentView`'s
    /// required `registry` parameter. Production push/pop bookkeeping for this flow
    /// lives in the navigator's `sessionsByToken`/`pendingNavigations`, not here.
    let registry = AppScreensPageRegistry()

    private weak var navigator: AppScreensDriver?

    init(
        navigator: AppScreensDriver,
        token: AppScreensToken = AppScreensToken(),
        isSheet: Bool = false
    ) {
        self.navigator = navigator
        self.token = token
        // isSheet reserved for a future divergence; release already handles a
        // sheet flow (no rootSessions entry → every owned session handlePop'd).
        _ = isSheet
    }

    deinit {
        // A `@StateObject` deallocates on the main thread when its owning view is
        // torn down, so the main-actor navigator is safe to touch here;
        // `assumeIsolated` bridges the nonisolated `deinit` to it (mirroring
        // `ExperienceViewController.deinit`'s release-on-teardown pattern).
        let capturedToken = token
        MainActor.assumeIsolated {
            navigator?.release(capturedToken)
        }
    }
}

/// Hosts `AppScreensContentView` directly on a caller-owned `NavigationPath`,
/// wiring it to the production `AppScreensDriver` singleton. `AppScreensDriver`
/// and `AppScreensPageViewController` are `internal` to RoverExperiences, so callers in
/// other modules (e.g. RoverNotifications' Hub) cannot name them directly — this
/// `package` view is the seam: it builds the production `makeScreen` closure and
/// replicates the App Screens domain gate so the caller only ever deals with
/// a `URL` and a `NavigationPath` binding.
package struct AppScreensHostView: View {
    let url: URL
    @Binding var path: NavigationPath
    let onDismiss: (() -> Void)?
    let onOpenURL: ((URL) -> Void)?
    /// The owner's completion-capable dismiss-then-open handler: registered
    /// for the root flow via `makeRootHost` and threaded down to every sheet flow this
    /// experience presents. `nil` default preserves existing callers.
    let onOpenExternalURL: ((URL, Bool) -> Void)?
    private let navigator: AppScreensDriver

    @StateObject private var tokenBox: AppScreensTokenBox
    @StateObject private var sheetCollapse = AppScreensSheetCollapseCoordinator()

    package init(
        url: URL,
        path: Binding<NavigationPath>,
        onDismiss: (() -> Void)?,
        onOpenURL: ((URL) -> Void)?,
        onOpenExternalURL: ((URL, Bool) -> Void)? = nil
    ) {
        let resolved = Rover.shared.resolve(AppScreensDriver.self)!
        self.url = url
        self._path = path
        self.onDismiss = onDismiss
        self.onOpenURL = onOpenURL
        self.onOpenExternalURL = onOpenExternalURL
        self.navigator = resolved
        self._tokenBox = StateObject(wrappedValue: AppScreensTokenBox(navigator: resolved))
    }

    package var body: some View {
        // Deep links arrive with a custom scheme; normalize to https before the
        // domain gate, mirroring `ExperienceViewController.loadAppScreensExperience`'s
        // normalization exactly, so a direct Hub-hosted App Screens flow
        // enforces the same associated-domains gate the legacy path did.
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return AnyView(EmptyView())
        }
        urlComponents.scheme = "https"

        guard let normalizedURL = urlComponents.url else {
            return AnyView(EmptyView())
        }

        let router = Rover.shared.resolve(Router.self)!
        guard router.isValidDomain(for: normalizedURL) else {
            os_log(
                "Refusing to load App Screens experience from unauthorized domain: %s",
                log: .appScreens,
                type: .error,
                normalizedURL.toString()
            )
            return AnyView(EmptyView())
        }

        return AnyView(
            AppScreensContentView(
                rootURL: normalizedURL,
                path: $path,
                registry: tokenBox.registry,
                makeScreen: { request in
                    switch request.role {
                    case .root:
                        return navigator.makeRootHost(
                            token: tokenBox.token,
                            url: request.targetRequest?.url ?? request.address.url,
                            navigating: request.navigating,
                            onDismiss: onDismiss,
                            onOpenURL: onOpenURL,
                            onOpenExternalURL: onOpenExternalURL
                        )
                    case .pushed:
                        return navigator.makeHost(
                            token: tokenBox.token,
                            address: request.address,
                            targetRequest: request.targetRequest,
                            navigating: request.navigating
                        )
                    case .sheetRoot:
                        // A sheet root is a pool session claimed via makeHost under this
                        // flow's token, symmetric with .pushed. (In practice each sheet
                        // builds its own makeScreen in AppScreensSheetHostView; this arm
                        // keeps the production factory total + correct.)
                        return navigator.makeHost(
                            token: tokenBox.token,
                            address: request.address,
                            targetRequest: request.targetRequest,
                            navigating: request.navigating
                        )
                    }
                },
                onPopScreen: { host in navigator.handlePop(forHostedBy: host) },
                onOpenExternalURL: onOpenExternalURL,
                sheetCollapse: sheetCollapse
            )
            .syncAppScreensOpenHandler(onOpenExternalURL, for: tokenBox.token, on: navigator)
        )
    }
}

/// Re-registers a flow's dismiss-then-open handler when it is published AFTER the
/// root screen was created. `makeRootHost` registers the handler exactly once, at
/// root-screen creation — but `HubHostingController` publishes the real handler only
/// at `viewWillAppear`, which lands after creation whenever the host app preloads
/// the controller's view before presenting, or renders the Hub embedded and presents
/// the same instance modally later. Without this sync, `openHandlersByToken` stays
/// stuck at its creation-time `nil` and a root-fired `openURL {dismiss:true}` opens
/// without dismissing the Hub.
///
/// Keyed on the handler's *presence* (`Bool` is `Equatable`, closures are not),
/// which is exactly the transition `HubHostingController` performs: `nil` while
/// embedded, a real closure once confirmed modal, and back. Sheet flows need no
/// equivalent — `AppScreensSheetHostView` registers at sheet-root render, which is
/// always after the flip.
private struct AppScreensOpenHandlerSync: ViewModifier {
    let handler: ((URL, Bool) -> Void)?
    let token: AppScreensToken
    let navigator: AppScreensDriver

    func body(content: Content) -> some View {
        content.onChange(of: handler != nil) { _, _ in
            navigator.registerOpenHandler(handler, for: token)
        }
    }
}

extension View {
    /// Keeps `navigator.openHandlersByToken[token]` in sync with a late-published
    /// dismiss-then-open handler — see ``AppScreensOpenHandlerSync``.
    func syncAppScreensOpenHandler(
        _ handler: ((URL, Bool) -> Void)?,
        for token: AppScreensToken,
        on navigator: AppScreensDriver
    ) -> some View {
        modifier(AppScreensOpenHandlerSync(handler: handler, token: token, navigator: navigator))
    }
}

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
import SafariServices
import SwiftUI
import UIKit

/// One screen's presented-sheet intent: the target request plus the flow token
/// `navigate` minted for this presentation, so the sheet container that
/// renders it can inject that same token into its own `AppScreensTokenBox`.
private struct SheetDestination: Identifiable {
    let request: URLRequest
    let sheetToken: AppScreensToken
    var id: String { request.url?.absoluteString ?? "" }
}

/// Wraps `SFSafariViewController` for the per-screen `presentWebsite` intent.
/// Mirrors `ScreenView.swift`'s `SafariView` (which is `private` there, so not
/// reusable across files); `SafariURL` itself IS reused from `ScreenView.swift`.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // no-op
    }
}

/// The single embedding view for App Screens. It does **not** own a `NavigationStack`:
/// it registers a `navigationDestination` on the host's stack and pushes `AppScreenDestination`
/// values onto the provided `path` binding, so the host (e.g. the Hub's `HubCoordinator`)
/// owns navigation. Each destination carries the full target `URLRequest`, so query
/// parameters and headers are preserved on the path itself — no side-dictionary. Sheet
/// presentations reuse this same view inside a self-contained `NavigationStack`.
package struct AppScreensContentView: View {
    private let rootRequest: URLRequest
    @Binding private var path: NavigationPath
    private let registry: AppScreensPageRegistry
    private let makeScreen: (AppScreensPageRequest) -> UIViewController
    /// The production dismantle-driven pop hook, wired only to `navigationDestination`
    /// entries (`.pushed` screens) — never the stack root, whose teardown is owned by
    /// `release`. `nil` default preserves Phase 1 callers that don't yet wire pop
    /// handling.
    private let onPopScreen: ((UIViewController) -> Void)?
    /// The role tagged onto the stack root screen: `.root` for a Hub-owned stack root
    /// (the default), `.sheetRoot` when this view is embedded as the root of a
    /// self-contained sheet flow (see `AppScreensSheetHostView`), so `makeScreen` never
    /// mistakes a sheet root for the production root host.
    private let rootRole: AppScreensPageRole
    /// The owner's completion-capable dismiss-then-open handler, threaded down to each
    /// `AppScreensPageView` so a sheet-hosted `AppScreensSheetHostView` can register it for its
    /// own flow token. `nil` default preserves existing callers that don't yet
    /// wire the seam.
    private let onOpenExternalURL: ((URL, Bool) -> Void)?
    /// The per-flow embedded-collapse coordinator. Required (no default) so a
    /// caller can never silently receive a throwaway coordinator — it is threaded down to
    /// each `AppScreensPageView` and on to nested `AppScreensSheetHostView`s.
    private let sheetCollapse: AppScreensSheetCollapseCoordinator

    @Environment(\.dismiss) private var dismiss

    package init(
        rootURL: URL,
        path: Binding<NavigationPath>,
        registry: AppScreensPageRegistry,
        makeScreen: @escaping (AppScreensPageRequest) -> UIViewController,
        onPopScreen: ((UIViewController) -> Void)? = nil,
        rootRole: AppScreensPageRole = .root,
        onOpenExternalURL: ((URL, Bool) -> Void)? = nil,
        sheetCollapse: AppScreensSheetCollapseCoordinator
    ) {
        self.init(
            rootRequest: URLRequest(url: rootURL),
            path: path,
            registry: registry,
            makeScreen: makeScreen,
            onPopScreen: onPopScreen,
            rootRole: rootRole,
            onOpenExternalURL: onOpenExternalURL,
            sheetCollapse: sheetCollapse
        )
    }

    package init(
        rootRequest: URLRequest,
        path: Binding<NavigationPath>,
        registry: AppScreensPageRegistry,
        makeScreen: @escaping (AppScreensPageRequest) -> UIViewController,
        onPopScreen: ((UIViewController) -> Void)? = nil,
        rootRole: AppScreensPageRole = .root,
        onOpenExternalURL: ((URL, Bool) -> Void)? = nil,
        sheetCollapse: AppScreensSheetCollapseCoordinator
    ) {
        self.rootRequest = rootRequest
        self._path = path
        self.registry = registry
        self.makeScreen = makeScreen
        self.onPopScreen = onPopScreen
        self.rootRole = rootRole
        self.onOpenExternalURL = onOpenExternalURL
        self.sheetCollapse = sheetCollapse
    }

    package var body: some View {
        Group {
            if let rootURL = rootRequest.url, let rootAddress = AppScreenAddress(rawURL: rootURL) {
                AppScreensPageView(
                    address: rootAddress,
                    request: rootRequest,
                    role: rootRole,
                    onDismantle: nil,
                    registry: registry,
                    makeScreen: makeScreen,
                    path: $path,
                    dismissRoot: { dismiss() },
                    onOpenExternalURL: onOpenExternalURL,
                    sheetCollapse: sheetCollapse
                )
                .navigationDestination(for: AppScreenDestination.self) { destination in
                    AppScreensPageView(
                        address: destination.address,
                        request: destination.request,
                        role: .pushed,
                        onDismantle: onPopScreen,
                        registry: registry,
                        makeScreen: makeScreen,
                        path: $path,
                        dismissRoot: { dismiss() },
                        onOpenExternalURL: onOpenExternalURL,
                        sheetCollapse: sheetCollapse
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
}

/// One hosted App Screen (the stack root or a pushed destination) plus the per-screen
/// modal state it owns. Mirrors `ScreenView`'s per-screen `.sheet(item:)` /
/// `.fullScreenCover(item:)` ownership: the `presentSheet` intent sets THIS screen's
/// `sheetDestination` and the `presentWebsite` intent sets THIS screen's `safariURL`;
/// an external navigation-path change auto-dismisses both.
private struct AppScreensPageView: View {
    let address: AppScreenAddress
    let request: URLRequest
    let role: AppScreensPageRole
    let onDismantle: ((UIViewController) -> Void)?
    let registry: AppScreensPageRegistry
    let makeScreen: (AppScreensPageRequest) -> UIViewController
    @Binding var path: NavigationPath
    let dismissRoot: () -> Void
    let onOpenExternalURL: ((URL, Bool) -> Void)?
    let sheetCollapse: AppScreensSheetCollapseCoordinator

    @State private var sheetDestination: SheetDestination?
    @State private var safariURL: SafariURL?
    /// This screen's bottom-sheet registration id with the collapse coordinator, held so
    /// dismissal can deregister exactly its own registration (never a newer sheet's).
    @State private var bottomSheetID: UUID?
    /// The flow token of the sheet this screen currently presents, held so `onDismiss`
    /// can name it: SwiftUI has already cleared `sheetDestination` by the time that
    /// callback runs, and the reveal the dismissal causes is reported against it.
    @State private var presentedSheetToken: AppScreensToken?

    var body: some View {
        AppScreensPageRepresentable(
            role: role,
            address: address,
            targetRequest: request,
            registry: registry,
            makeScreen: makeScreen,
            push: { pushedAddress, pushedRequest in
                let resolvedRequest = pushedRequest ?? URLRequest(url: pushedAddress.url)
                guard let destination = AppScreenDestination(request: resolvedRequest) else {
                    return
                }
                path.append(destination)
            },
            presentSheet: { sheetAddress, sheetRequest, sheetToken in
                sheetDestination = SheetDestination(
                    request: sheetRequest ?? URLRequest(url: sheetAddress.url),
                    sheetToken: sheetToken
                )
                presentedSheetToken = sheetToken
            },
            presentWebsite: { url in safariURL = SafariURL(url: url) },
            dismissRoot: dismissRoot,
            onDismantle: onDismantle
        )
        .ignoresSafeArea()
        // Every hosted App Screen pins its own navigation item: pushed destinations,
        // the sheet root, and warm-restored pages all get fresh bar state seeded from
        // the host app's appearance proxy, and the stack root's reset never reaches them.
        .resetNavBarAppearance(.transparent)
        .sheet(
            item: $sheetDestination,
            onDismiss: {
                // Analytics first, and from here rather than from the sheet flow's
                // teardown: this callback runs once the dismissal transition is done, so
                // the screen this sheet was covering is genuinely on screen again (its
                // host's `presentedViewController` is nil) — a page sheet delivers it no
                // `viewDidAppear`, so this is the only signal that it was revealed.
                if let sheetToken = presentedSheetToken {
                    presentedSheetToken = nil
                    Rover.shared.resolve(AppScreensDriver.self)?.sheetFlowDidDismiss(sheetToken)
                }
                sheetCollapse.sheetDidDismiss()
                if let id = bottomSheetID {
                    sheetCollapse.deregisterBottomSheet(id: id)
                    bottomSheetID = nil
                }
            }
        ) { sheet in
            AppScreensSheetHostView(
                rootRequest: sheet.request,
                sheetToken: sheet.sheetToken,
                navigator: Rover.shared.resolve(AppScreensDriver.self)!,
                onOpenExternalURL: onOpenExternalURL,
                sheetCollapse: sheetCollapse
            )
        }
        .fullScreenCover(item: $safariURL) { safari in
            SafariView(url: safari.url).ignoresSafeArea()
        }
        .onChange(of: sheetDestination?.id) { _, newID in
            let clearBinding = $sheetDestination
            if newID != nil {
                // Present: record this as a candidate bottom sheet (first-wins in the coordinator).
                bottomSheetID = sheetCollapse.registerBottomSheet(clear: { clearBinding.wrappedValue = nil })
            } else if let id = bottomSheetID {
                // Cleared (incl. via the existing onChange(of: path) reset, which nils the
                // binding without necessarily routing through onDismiss first): deregister
                // here too so a registration can't linger.
                sheetCollapse.deregisterBottomSheet(id: id)
                bottomSheetID = nil
            }
        }
        .onChange(of: path) { _, _ in
            // Mirror ScreenView: an external navigation-path change (e.g. a
            // coordinator-driven reset) dismisses any sheet or in-app browser this
            // screen presents.
            sheetDestination = nil
            safariURL = nil
        }
    }
}

/// A self-contained App Screen flow presented as a sheet. It owns its own
/// `AppScreensTokenBox` — initialized with the flow token `navigate` minted for this
/// presentation — so the box's `deinit → release(token)` returns the
/// sheet's warm sessions to the pool / tears down its ephemerals. Its own production
/// `makeScreen` claims every screen (sheet root + in-sheet pushes) via `makeHost`
/// under that injected token: unlike `AppScreensHostView`, a sheet flow has no
/// `makeRootHost` entry-root — the sheet root is a pool session.
@MainActor
private struct AppScreensSheetHostView: View {
    let rootRequest: URLRequest
    private let navigator: AppScreensDriver
    /// The owner's dismiss-then-open handler, registered for this sheet's own flow
    /// token when its root screen renders — NOT stored on `tokenBox`, since the
    /// box only carries identity/registry state that must survive re-creation.
    private let onOpenExternalURL: ((URL, Bool) -> Void)?
    /// The per-flow embedded-collapse coordinator, threaded from the presenting
    /// `AppScreensPageView`. When no owner handler is injected (embedded Hub), the registered
    /// wrapper routes `openURL` through this coordinator to collapse the sheet stack.
    private let sheetCollapse: AppScreensSheetCollapseCoordinator

    @State private var path = NavigationPath()
    @StateObject private var tokenBox: AppScreensTokenBox
    /// Dismisses the whole sheet presentation (not a stack pop): this view is the
    /// direct content of the presenting screen's `.sheet(item:)`, so its
    /// `\.dismiss` clears that `sheetDestination` binding, which drives
    /// `AppScreensTokenBox.deinit → release(token)` exactly like a swipe-down.
    @Environment(\.dismiss) private var dismiss

    init(
        rootRequest: URLRequest,
        sheetToken: AppScreensToken,
        navigator: AppScreensDriver,
        onOpenExternalURL: ((URL, Bool) -> Void)? = nil,
        sheetCollapse: AppScreensSheetCollapseCoordinator
    ) {
        self.rootRequest = rootRequest
        self.navigator = navigator
        self.onOpenExternalURL = onOpenExternalURL
        self.sheetCollapse = sheetCollapse
        self._tokenBox = StateObject(
            wrappedValue: AppScreensTokenBox(navigator: navigator, token: sheetToken, isSheet: true)
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppScreensContentView(
                rootRequest: rootRequest,
                path: $path,
                registry: tokenBox.registry,
                makeScreen: { request in
                    // Sheet root AND in-sheet pushes are pool sessions claimed via
                    // makeHost under this sheet's injected flow token (there is no
                    // makeRootHost entry-root in a sheet flow). Register the owner's
                    // open handler for this flow token when the sheet root renders, so
                    // every screen in this sheet (root + in-sheet pushes) resolves the
                    // same owner handler.
                    if request.role == .sheetRoot {
                        let owner = onOpenExternalURL
                        let coordinator = sheetCollapse
                        navigator.registerOpenHandler(
                            { url, shouldDismiss in
                                if let owner {
                                    owner(url, shouldDismiss)  // presented Hub dismisses itself + opens
                                } else {
                                    coordinator.handleOpenExternal(url, dismiss: shouldDismiss)  // embedded collapse
                                }
                            },
                            for: tokenBox.token
                        )
                    }
                    return navigator.makeHost(
                        token: tokenBox.token,
                        address: request.address,
                        targetRequest: request.targetRequest,
                        navigating: request.navigating
                    )
                },
                onPopScreen: { host in navigator.handlePop(forHostedBy: host) },
                rootRole: .sheetRoot,
                onOpenExternalURL: onOpenExternalURL,
                sheetCollapse: sheetCollapse
            )
            // develop's UIKit sheet installs an xmark on its `UINavigationController`
            // root; this SwiftUI sheet had only swipe-to-dismiss. Force the bar visible
            // (the hosted screen `.ignoresSafeArea`, which would otherwise collapse it)
            // and add the same close affordance, dismissing the sheet presentation.
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppScreensCloseButton { dismiss() }
                }
            }
        }
    }
}

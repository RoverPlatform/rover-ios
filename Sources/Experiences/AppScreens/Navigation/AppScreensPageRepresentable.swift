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
import UIKit

/// Discriminates the position of a hosted App Screen within its navigation container,
/// so a single `makeScreen` closure can route to the correct host factory: `.root` is
/// the base of a Hub-owned `NavigationStack` (routes to `makeRootHost`), `.pushed` is a
/// `navigationDestination` entry (routes to `makeHost`), and `.sheetRoot` is the root of
/// a self-contained sheet-presented flow (must never be routed to `makeRootHost`).
package enum AppScreensPageRole {
    case root
    case pushed
    case sheetRoot
}

/// The inputs `AppScreensContentView` hands its `makeScreen` factory to vend one
/// screen's host view controller. Passing a single value keeps the factory signature
/// stable as inputs evolve and removes positional-argument mistakes at call sites.
package struct AppScreensPageRequest {
    /// Whether this screen is the stack root, a pushed detail, or a sheet root —
    /// so production routing can pick makeRootHost / makeHost / a sheet factory.
    package let role: AppScreensPageRole
    /// The canonical App Screen identity to render.
    package let address: AppScreenAddress
    /// The full target request (query/headers/body) for the screen, if any.
    package let targetRequest: URLRequest?
    /// The per-screen navigator the hosted screen pushes/presents through.
    package let navigating: AppScreensNavigating

    package init(
        role: AppScreensPageRole,
        address: AppScreenAddress,
        targetRequest: URLRequest?,
        navigating: AppScreensNavigating
    ) {
        self.role = role
        self.address = address
        self.targetRequest = targetRequest
        self.navigating = navigating
    }
}

/// The representable's coordinator: it holds the navigator the hosted screen talks to,
/// plus the registry + address so the static `dismantleUIViewController` hook (which
/// receives only the VC and coordinator) can record the pop.
@MainActor
package final class AppScreensPageCoordinator {
    package let navigator: AppScreensNavigator
    package let registry: AppScreensPageRegistry
    package let address: AppScreenAddress
    package let onDismantle: ((UIViewController) -> Void)?

    package init(
        navigator: AppScreensNavigator,
        registry: AppScreensPageRegistry,
        address: AppScreenAddress,
        onDismantle: ((UIViewController) -> Void)?
    ) {
        self.navigator = navigator
        self.registry = registry
        self.address = address
        self.onDismantle = onDismantle
    }
}

/// Hosts a single App Screen inside a SwiftUI `NavigationStack`. `makeUIViewController`
/// records the push and vends the screen (wired to the coordinator's navigator);
/// `dismantleUIViewController` — SwiftUI's teardown hook, fired when the destination
/// leaves the `NavigationPath` — records the pop. This replaces the UIKit
/// `viewDidDisappear` + `isMovingFromParent` signal, which is unreliable for a child of
/// a SwiftUI-owned hosting controller.
package struct AppScreensPageRepresentable: UIViewControllerRepresentable {
    package typealias Coordinator = AppScreensPageCoordinator

    let role: AppScreensPageRole
    let address: AppScreenAddress
    let targetRequest: URLRequest?
    let registry: AppScreensPageRegistry
    let makeScreen: (AppScreensPageRequest) -> UIViewController
    let push: (AppScreenAddress, URLRequest?) -> Void
    let presentSheet: (AppScreenAddress, URLRequest?, AppScreensToken) -> Void
    let presentWebsite: (URL) -> Void
    let dismissRoot: () -> Void
    /// The production pop hook for `.pushed` screens: fired from `dismantleUIViewController`
    /// alongside `registry.didPop` (see there). `nil` for the root screen, whose teardown is
    /// owned by `release` instead.
    let onDismantle: ((UIViewController) -> Void)?

    package func makeCoordinator() -> AppScreensPageCoordinator {
        let navigator = AppScreensNavigator(push: push, presentSheet: presentSheet, dismissRoot: dismissRoot)
        navigator.websiteHandler = presentWebsite
        return AppScreensPageCoordinator(
            navigator: navigator,
            registry: registry,
            address: address,
            onDismantle: onDismantle
        )
    }

    package func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.registry.didPush(context.coordinator.address)
        return makeScreen(
            AppScreensPageRequest(
                role: role,
                address: context.coordinator.address,
                targetRequest: targetRequest,
                navigating: context.coordinator.navigator
            )
        )
    }

    package func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Refresh the closures so they never capture stale SwiftUI state.
        context.coordinator.navigator.pushHandler = push
        context.coordinator.navigator.sheetHandler = presentSheet
        context.coordinator.navigator.dismissHandler = dismissRoot
        context.coordinator.navigator.websiteHandler = presentWebsite
    }

    package static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: AppScreensPageCoordinator
    ) {
        // Phase 1's de-risk tests assert against the registry directly; keep recording
        // here regardless of `onDismantle`.
        coordinator.registry.didPop(coordinator.address)
        // The production pop hook: resolves the session by host and runs the
        // keep-warm-vs-teardown decision. `nil` for the root screen.
        coordinator.onDismantle?(uiViewController)
    }
}

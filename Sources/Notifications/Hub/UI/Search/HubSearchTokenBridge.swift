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

/// Owns the search field's token chip so it can carry the real subscription
/// logo or sender avatar — `UISearchToken(icon:)` supports images, which
/// SwiftUI's token binding does not.
///
/// A hidden bridge view locates the `UISearchTextField` backing the enclosing
/// `.searchable` modifier and manages its `tokens` directly, syncing chip
/// deletion back into SwiftUI state. Discovery is scoped to the Hub's own
/// navigation stack (found by walking up the responder chain), so a search
/// field owned by the host app can never be touched. If no field is found,
/// `onAttachFailure` fires so the caller can fall back to SwiftUI-managed
/// tokens instead — the chip is then a plain symbol, but never missing.
struct HubSearchTokenBridge: UIViewRepresentable {
    let token: HubSearchToken?
    let onTokenRemoved: () -> Void
    let onAttachFailure: () -> Void

    func makeUIView(context: Context) -> BridgeView {
        BridgeView()
    }

    func updateUIView(_ view: BridgeView, context: Context) {
        view.onTokenRemoved = onTokenRemoved
        view.onAttachFailure = onAttachFailure
        view.apply(token: token)
    }

    final class BridgeView: UIView {
        var onTokenRemoved: (() -> Void)?
        var onAttachFailure: (() -> Void)?

        private weak var field: UISearchTextField?
        private var currentToken: HubSearchToken?
        private var pendingToken: HubSearchToken?
        private var observer: NSObjectProtocol?
        private var iconTask: Task<Void, Never>?
        private var attachRetryTask: Task<Void, Never>?
        private var attachRetryGeneration = 0

        private static let maxAttachRetries = 3
        private static let attachRetryInterval: Duration = .milliseconds(50)

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                // A detached bridge must not conclude anything about the
                // field — cancel the chain but keep pendingToken so a
                // reattachment picks the token straight back up.
                attachRetryTask?.cancel()
                attachRetryTask = nil
                return
            }
            subscribeIfNeeded()
            if let pendingToken {
                apply(token: pendingToken)
            }
        }

        func apply(token: HubSearchToken?) {
            guard let field = resolveField() else {
                pendingToken = token
                if token != nil, window != nil {
                    scheduleAttachRetries()
                }
                return
            }
            pendingToken = nil

            guard let token else {
                iconTask?.cancel()
                if currentToken != nil {
                    field.tokens = []
                    currentToken = nil
                }
                return
            }
            // Re-apply when any part of the token changed (a rename or new
            // image URL for the same id must refresh the chip) or when the
            // field instance changed (e.g. search was dismissed and reopened).
            guard token != currentToken || field.tokens.isEmpty else { return }
            currentToken = token
            iconTask?.cancel()

            // A cache hit resolves synchronously (the suggestion row the user
            // just tapped has normally cached this URL already), so the chip
            // is born with the avatar and never flickers through the fallback.
            if let url = token.imageURL, let cached = ImageCache.shared.image(for: url) {
                field.tokens = [makeToken(for: token, icon: Self.icon(from: cached, for: token))]
                return
            }

            field.tokens = [makeToken(for: token, icon: nil)]
            iconTask = Task { @MainActor [weak self, weak field] in
                guard let image = await Self.loadImage(for: token) else { return }
                guard
                    let self, let field, !Task.isCancelled,
                    self.currentToken == token
                else { return }
                let icon = Self.icon(from: image, for: token)
                field.tokens = [self.makeToken(for: token, icon: icon)]
            }
        }

        /// A single retry chain: the field may genuinely not exist yet when a
        /// token is first wanted (SwiftUI builds the searchable field
        /// asynchronously, e.g. during state restoration), so discovery is
        /// retried a few times before conceding. Only one chain runs at a
        /// time, every hop re-resolves the field, and the failure callback
        /// fires only inside the chain directly after a failed resolve — so a
        /// field discovered mid-chain can never be followed by a stale
        /// failure. Callbacks stay off the `updateUIView` call stack, where
        /// mutating SwiftUI state is not allowed.
        private func scheduleAttachRetries() {
            guard attachRetryTask == nil else { return }
            attachRetryGeneration += 1
            let generation = attachRetryGeneration
            attachRetryTask = Task { @MainActor [weak self] in
                defer {
                    // Clear the handle only if it is still this chain's own —
                    // a cancelled chain's defer must not clear a successor
                    // scheduled after a rapid detach/reattach.
                    if let self, self.attachRetryGeneration == generation {
                        self.attachRetryTask = nil
                    }
                }
                for _ in 0..<Self.maxAttachRetries {
                    try? await Task.sleep(for: Self.attachRetryInterval)
                    // A withdrawn token or a detached bridge ends the chain
                    // without failing — off-window, nothing can be concluded
                    // about the field.
                    guard let self, !Task.isCancelled, self.window != nil else { return }
                    guard let pending = self.pendingToken else { return }
                    if self.resolveField() != nil {
                        self.apply(token: pending)
                        return
                    }
                }
                guard
                    let self, !Task.isCancelled, self.window != nil,
                    self.pendingToken != nil
                else { return }
                self.pendingToken = nil
                self.onAttachFailure?()
            }
        }

        // MARK: - Field discovery

        /// Finds the `UISearchTextField` inside the Hub's own navigation
        /// stack. The `.searchable` field lives in the navigation bar, so the
        /// search is rooted at the nearest ancestor `UINavigationController`'s
        /// view (or the nearest view controller's view when there is no
        /// navigation controller) — never the window, so a host app's search
        /// field elsewhere on screen is out of scope by construction.
        private func resolveField() -> UISearchTextField? {
            if let field, field.window != nil { return field }
            field = nil
            guard let root = searchScopeRoot() else { return nil }
            var queue: [UIView] = [root]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                if let found = view as? UISearchTextField {
                    field = found
                    return found
                }
                queue.append(contentsOf: view.subviews)
            }
            return nil
        }

        private func searchScopeRoot() -> UIView? {
            var responder: UIResponder? = next
            var nearestControllerView: UIView?
            while let current = responder {
                if let navigationController = current as? UINavigationController {
                    return navigationController.view
                }
                if let controller = current as? UIViewController {
                    if nearestControllerView == nil {
                        nearestControllerView = controller.view
                    }
                    if let navigationController = controller.navigationController {
                        return navigationController.view
                    }
                }
                responder = current.next
            }
            return nearestControllerView
        }

        // MARK: - Deletion sync

        private func subscribeIfNeeded() {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard
                    let self,
                    let changed = note.object as? UISearchTextField,
                    changed === self.field,
                    self.currentToken != nil,
                    changed.tokens.isEmpty
                else { return }
                self.currentToken = nil
                self.onTokenRemoved?()
            }
        }

        // MARK: - Icons

        private func makeToken(for token: HubSearchToken, icon: UIImage?) -> UISearchToken {
            if let icon {
                return UISearchToken(icon: icon, text: token.name)
            }
            let fallback =
                fallbackIcon(for: token).flatMap { Self.icon(from: $0, for: token) }
                ?? UIImage(systemName: token.systemImage)
            return UISearchToken(icon: fallback, text: token.name)
        }

        /// Renders the same fallback the suggestion rows show (gradient plus
        /// initials / logo glyph) so a missing image looks identical in the
        /// chip and the list.
        private func fallbackIcon(for token: HubSearchToken, diameter: CGFloat = 20) -> UIImage? {
            let content: AnyView
            switch token {
            case .subscription:
                content = AnyView(LogoView(url: nil, size: diameter))
            case .sender:
                content = AnyView(AvatarView(url: nil, name: token.name, size: diameter))
            }
            let renderer = ImageRenderer(
                content:
                    content
                    .tint(Color(uiColor: tintColor))
                    .environment(
                        \.colorScheme,
                        traitCollection.userInterfaceStyle == .dark ? .dark : .light
                    )
            )
            renderer.scale = window?.screen.scale ?? 3
            return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
        }

        /// Shares ImageCache with the suggestion rows, so tapping a suggestion
        /// normally reuses the avatar the row just loaded rather than
        /// downloading it again.
        @MainActor
        private static func loadImage(for token: HubSearchToken) async -> UIImage? {
            guard let url = token.imageURL else { return nil }
            if let cached = ImageCache.shared.image(for: url) {
                return cached
            }
            // URLSession.shared is intentional — image URLs are
            // unauthenticated CDN links (same rationale as CachedAsyncImage).
            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                let decoded = UIImage(data: data)
            else { return nil }
            ImageCache.shared.store(decoded, for: url)
            return decoded
        }

        /// Crops the image into the same shape the rows use for this token
        /// type — a circle for sender avatars, a rounded rectangle matching
        /// `LogoView`'s corner ratio for subscription logos.
        static func icon(
            from source: UIImage,
            for token: HubSearchToken,
            diameter: CGFloat = 20,
            inset: CGFloat = 1.5
        ) -> UIImage? {
            let size = CGSize(width: diameter, height: diameter)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                // The shape is inset within a transparent canvas so the
                // image keeps breathing room from the chip's edges even if
                // the chip scales the icon to fill its slot.
                let shapeRect = CGRect(origin: .zero, size: size)
                    .insetBy(dx: inset, dy: inset)
                let clip: UIBezierPath
                switch token {
                case .subscription:
                    clip = UIBezierPath(
                        roundedRect: shapeRect,
                        cornerRadius: shapeRect.width * (10 / 44)
                    )
                case .sender:
                    clip = UIBezierPath(ovalIn: shapeRect)
                }
                clip.addClip()
                let side = shapeRect.width
                let scale = max(side / source.size.width, side / source.size.height)
                let drawSize = CGSize(
                    width: source.size.width * scale,
                    height: source.size.height * scale
                )
                let origin = CGPoint(
                    x: shapeRect.midX - drawSize.width / 2,
                    y: shapeRect.midY - drawSize.height / 2
                )
                source.draw(in: CGRect(origin: origin, size: drawSize))
            }.withRenderingMode(.alwaysOriginal)
        }

        deinit {
            iconTask?.cancel()
            attachRetryTask?.cancel()
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

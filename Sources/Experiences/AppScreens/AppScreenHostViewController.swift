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

import UIKit
import WebKit

/// Thin chrome-only view controller that hosts a prepared web view behind a
/// native placeholder until the runtime reports that content has painted.
///
/// The placeholder starts as the plain screen background — matching how native
/// screens push with real chrome and let content arrive — and only escalates to
/// the skeleton shimmer if content isn't ready within a grace period, so fast
/// loads never flash a loading state.
///
/// The web view is optional: a host vended without one renders only the skeleton
/// (used before a session's web view is attached); a host with a web view drives
/// `reveal()` once the runtime reports content has painted.
@MainActor
final class AppScreenHostViewController: UIViewController {
    /// How long a screen may show plain background before the skeleton shimmer
    /// appears. Warm pushes hydrate in tens of milliseconds and never reach it;
    /// only genuinely slow (cold / first-ever) loads do.
    private static let skeletonGraceInterval: TimeInterval = 0.3

    private let webView: WKWebView?
    private let screenBackground: UIColor
    /// A re-hydrated template web view already shows real (previous) content that
    /// the next hydrate morphs in place, so it skips the skeleton entirely.
    private let showsSkeleton: Bool

    private lazy var skeletonView = AppScreenSkeletonView(placeholderBackground: screenBackground)
    private var skeletonGraceWorkItem: DispatchWorkItem?

    private var didReveal = false
    private var failureView: UIView?

    /// Invoked when this screen is popped off its navigation stack (not on
    /// dismissal of the whole stack). The navigator uses it to free or repurpose
    /// the session's web view.
    var onPopped: (() -> Void)?

    /// Invoked every time this screen becomes visible (its `viewDidAppear`). The
    /// navigator uses it to fire a *deferred* recovery: when an occluded (on-stack
    /// but not top) session's WebContent process dies, its runtime cannot boot
    /// off-screen, so recovery is postponed and run here, once the screen is on top
    /// again. Fires on the initial appear too; the navigator no-ops unless the
    /// session is flagged for recovery.
    var onBecameVisible: (() -> Void)?

    init(
        webView: WKWebView?,
        screenBackground: UIColor,
        showsSkeleton: Bool = true
    ) {
        self.webView = webView
        self.screenBackground = screenBackground
        self.showsSkeleton = showsSkeleton
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Backgrounds are set before anything loads so there is no white flash
        // before the content paints.
        view.backgroundColor = screenBackground

        // No `UINavigationBarAppearance` is pinned: the system default bar over
        // full-bleed content renders the back/close buttons as floating liquid-glass
        // capsules on iOS 26, and lets content scroll under a transparent bar.

        if let webView {
            webView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(webView)
            // The web view is pinned to the raw view edges (not the safe-area guide)
            // so content is edge-to-edge under the bar and status/home-indicator
            // insets. Pages own their safe-area padding via `env(safe-area-inset-*)`
            // with `viewport-fit=cover` per the document contract, so the native
            // chrome must not add its own top inset.
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: view.topAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }

        guard showsSkeleton else {
            return
        }

        skeletonView.translatesAutoresizingMaskIntoConstraints = false
        // Grace period: the placeholder is the plain screen background at first;
        // the shimmer fades in only if content hasn't revealed in time.
        skeletonView.alpha = 0
        view.addSubview(skeletonView)
        NSLayoutConstraint.activate([
            skeletonView.topAnchor.constraint(equalTo: view.topAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        scheduleSkeletonGrace()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Fires on the initial push and on every re-appear (e.g. popping back to
        // this screen). The navigator only acts on it when this session was flagged
        // for a deferred recovery while occluded.
        onBecameVisible?()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            onPopped?()
        }
    }

    /// Fades the skeleton shimmer in after the grace period, unless content
    /// revealed first.
    private func scheduleSkeletonGrace() {
        skeletonGraceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.didReveal else {
                return
            }
            UIView.animate(withDuration: 0.15) { self.skeletonView.alpha = 1 }
        }
        skeletonGraceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.skeletonGraceInterval, execute: work)
    }

    /// Crossfades the placeholder away, revealing the rendered content. Idempotent.
    func reveal() {
        guard showsSkeleton, !didReveal else {
            return
        }
        didReveal = true
        skeletonGraceWorkItem?.cancel()
        skeletonGraceWorkItem = nil
        UIView.animate(
            withDuration: 0.12,
            animations: { self.skeletonView.alpha = 0 },
            completion: { _ in self.skeletonView.removeFromSuperview() }
        )
    }

    /// Covers the screen with a minimal error state and a Retry button, so a
    /// failed fetch never presents as an infinite skeleton shimmer. Retry
    /// dismisses the error state (the skeleton resumes underneath) and invokes
    /// the handler.
    func showLoadFailure(onRetry: @escaping () -> Void) {
        loadViewIfNeeded()
        failureView?.removeFromSuperview()

        let label = UILabel()
        label.text = NSLocalizedString(
            "Couldn't load this screen.",
            comment: "Rover App Screens load failure message"
        )
        label.textColor = screenBackground.contrastingForeground.withAlphaComponent(0.7)
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textAlignment = .center

        var retryConfiguration = UIButton.Configuration.gray()
        retryConfiguration.title = NSLocalizedString(
            "Retry",
            comment: "Rover App Screens retry button title"
        )
        retryConfiguration.cornerStyle = .capsule
        let retry = UIButton(
            configuration: retryConfiguration,
            primaryAction: UIAction { [weak self] _ in
                self?.dismissLoadFailure()
                onRetry()
            }
        )

        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = screenBackground
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        failureView = container
    }

    private func dismissLoadFailure() {
        failureView?.removeFromSuperview()
        failureView = nil
        // The retry restarts a load, so re-arm the placeholder grace period.
        if showsSkeleton, !didReveal {
            scheduleSkeletonGrace()
        }
    }
}

extension UIColor {
    /// Black or white, whichever contrasts with this color — placeholder chrome
    /// (skeleton blocks, error text) must read on both light and dark screen
    /// backgrounds.
    var contrastingForeground: UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5 ? .black : .white
    }
}

/// A lightweight shimmering placeholder shown while a screen loads and hydrates.
final class AppScreenSkeletonView: UIView {
    private let gradientLayer = CAGradientLayer()
    private var blocks: [UIView] = []
    private let blockColor: UIColor

    init(placeholderBackground: UIColor) {
        blockColor = placeholderBackground.contrastingForeground
        super.init(frame: .zero)
        backgroundColor = placeholderBackground
        buildPlaceholderBlocks()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startShimmer()
        } else {
            gradientLayer.removeAllAnimations()
        }
    }

    private func buildPlaceholderBlocks() {
        // A header block plus a stack of row-shaped blocks approximating the list layout.
        let header = makeBlock(cornerRadius: 12)
        addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 24),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            header.widthAnchor.constraint(equalToConstant: 180),
            header.heightAnchor.constraint(equalToConstant: 34)
        ])
        blocks.append(header)

        var previous: UIView = header
        for _ in 0..<6 {
            let row = makeBlock(cornerRadius: 16)
            addSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 16),
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                row.heightAnchor.constraint(equalToConstant: 64)
            ])
            blocks.append(row)
            previous = row
        }

        gradientLayer.colors = [
            blockColor.withAlphaComponent(0.0).cgColor,
            blockColor.withAlphaComponent(0.08).cgColor,
            blockColor.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradientLayer)
    }

    private func makeBlock(cornerRadius: CGFloat) -> UIView {
        let block = UIView()
        block.backgroundColor = blockColor.withAlphaComponent(0.08)
        block.layer.cornerRadius = cornerRadius
        return block
    }

    private func startShimmer() {
        gradientLayer.removeAllAnimations()
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.4
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmer")
    }
}

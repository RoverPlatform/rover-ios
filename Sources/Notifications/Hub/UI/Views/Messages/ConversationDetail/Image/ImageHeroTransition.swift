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

import AVFoundation
import UIKit

// MARK: - Shared helpers

private func makeSnapshot(_ uiImage: UIImage, frame: CGRect, in container: UIView) -> UIImageView {
    let imageView = UIImageView(image: uiImage)
    imageView.contentMode = .scaleAspectFit
    imageView.frame = frame
    container.addSubview(imageView)
    return imageView
}

// MARK: - Presentation animator

/// Animates a floating UIImageView snapshot from the source bubble to the full-screen destination.
/// Falls back to a simple fade when the image is not in ImageCache.
private final class ImageHeroPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let sourceFrame: CGRect
    let url: URL
    let dimmingView: UIView

    init(sourceFrame: CGRect, url: URL, dimmingView: UIView) {
        self.sourceFrame = sourceFrame
        self.url = url
        self.dimmingView = dimmingView
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.4
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let toVC = context.viewController(forKey: .to),
            let toView = context.view(forKey: .to)
        else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let finalFrame = context.finalFrame(for: toVC)

        dimmingView.frame = container.bounds
        dimmingView.alpha = 0
        container.addSubview(dimmingView)

        toView.frame = finalFrame
        toView.alpha = 0
        container.addSubview(toView)

        guard let uiImage = ImageCache.shared.image(for: url), !sourceFrame.isEmpty else {
            UIView.animate(withDuration: 0.3) {
                toView.alpha = 1
                self.dimmingView.alpha = 1
            } completion: { finished in
                if !finished { self.dimmingView.removeFromSuperview() }
                context.completeTransition(finished)
            }
            return
        }

        // FullScreenImageView respects safe areas, so the SwiftUI scaledToFit image is
        // centered within the inset rect — not the full finalFrame. Using the same inset
        // here ensures the snapshot lands exactly where the image will appear.
        let contentFrame = finalFrame.inset(by: container.safeAreaInsets)
        let destRect = AVMakeRect(aspectRatio: uiImage.size, insideRect: contentFrame)
        let imageView = makeSnapshot(uiImage, frame: sourceFrame, in: container)

        UIView.animate(
            withDuration: transitionDuration(using: context),
            delay: 0,
            usingSpringWithDamping: 0.96,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            imageView.frame = destRect
            self.dimmingView.alpha = 1
        } completion: { finished in
            UIView.animate(withDuration: 0.1) {
                imageView.alpha = 0
                toView.alpha = 1
                // The crossfade is cosmetic; use the outer animation's `finished` for transition completion.
            } completion: { _ in
                imageView.removeFromSuperview()
                context.completeTransition(finished)
            }
        }
    }
}

// MARK: - Dismissal animator

/// Animates the floating UIImageView snapshot back to the source bubble on dismissal.
/// Falls back to a simple fade when the image is not in ImageCache.
private final class ImageHeroDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let sourceFrame: CGRect
    let url: URL
    let dimmingView: UIView

    init(sourceFrame: CGRect, url: URL, dimmingView: UIView) {
        self.sourceFrame = sourceFrame
        self.url = url
        self.dimmingView = dimmingView
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.35
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let fromView = context.view(forKey: .from) else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView

        guard let uiImage = ImageCache.shared.image(for: url), !sourceFrame.isEmpty else {
            UIView.animate(withDuration: 0.3) {
                fromView.alpha = 0
                self.dimmingView.alpha = 0
            } completion: { finished in
                self.dimmingView.removeFromSuperview()
                context.completeTransition(finished)
            }
            return
        }

        let contentFrame = container.bounds.inset(by: container.safeAreaInsets)
        let destRect = AVMakeRect(aspectRatio: uiImage.size, insideRect: contentFrame)

        fromView.alpha = 0
        let imageView = makeSnapshot(uiImage, frame: destRect, in: container)

        // Dismiss is slightly faster than present to feel snappier.
        UIView.animate(
            withDuration: transitionDuration(using: context),
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: .curveEaseInOut
        ) {
            imageView.frame = self.sourceFrame
            self.dimmingView.alpha = 0
        } completion: { finished in
            imageView.removeFromSuperview()
            self.dimmingView.removeFromSuperview()
            context.completeTransition(finished)
        }
    }
}

// MARK: - Transition delegate

/// Vends the correct animator for presentation and dismissal.
/// Owns the `dimmingView` so it persists across both animations.
/// Stores a weak reference to the source view so `sourceFrame` can be computed fresh at
/// dismiss time — giving correct coordinates even if the device rotated while the image was open.
/// Retain this on the presenting view controller for the lifetime of the presented controller.
final class ImageHeroTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private weak var sourceView: UIView?
    private let url: URL

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    init(sourceView: UIView, url: URL) {
        self.sourceView = sourceView
        self.url = url
    }

    private var currentSourceFrame: CGRect {
        guard let sourceView, let window = sourceView.window else { return .zero }
        return sourceView.convert(sourceView.bounds, to: window)
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImageHeroPresentAnimator(sourceFrame: currentSourceFrame, url: url, dimmingView: dimmingView)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImageHeroDismissAnimator(sourceFrame: currentSourceFrame, url: url, dimmingView: dimmingView)
    }
}

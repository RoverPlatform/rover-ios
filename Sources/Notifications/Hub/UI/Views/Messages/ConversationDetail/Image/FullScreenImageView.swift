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

/// Full-screen image viewer presented by the hero transition when the user taps a chat image.
///
/// The view itself has no background — the black dimming layer is managed by
/// `ImageHeroTransitionDelegate` so it can fade independently of the zoom animation.
///
/// Supports:
/// - Pinch-to-zoom with drag-to-pan when zoomed in
/// - Double-tap to reset zoom and pan
/// - Swipe-down to dismiss when at 1× zoom
struct FullScreenImageView: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let zoomSpringResponse: Double = 0.3
    private let swipeDownDismissThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { proxy in
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: zoomSpringResponse)) {
                                resetZoom()
                            }
                        }
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .failure:
                    Image(systemName: "photo.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.4))
                        .padding()
                }
                .padding(.top, 8)
            }
            .onChange(of: proxy.size) { _, _ in
                resetZoom()
            }
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, lastScale * value)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // Only track downward drag at 1× — swipe-down-to-dismiss.
                    offset = CGSize(width: 0, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else {
                    if value.translation.height > swipeDownDismissThreshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: zoomSpringResponse)) {
                            offset = .zero
                        }
                    }
                    lastOffset = .zero
                }
            }
    }
}

/// UIHostingController subclass that allows landscape rotation for the full-screen image viewer.
/// The rest of the app is portrait-only; this VC opts in to all orientations independently.
final class FullScreenImageHostingController: UIHostingController<FullScreenImageView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .all
    }
}

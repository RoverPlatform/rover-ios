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

/// Loads and displays a remote image with a loading/failure placeholder.
/// When `onTap` is provided, the image becomes tappable and the handler receives
/// the source `UIView` so callers can compute window-space coordinates at any time
/// (e.g. at hero-transition dismiss time after a device rotation).
struct TappableAsyncImage: View {
    let url: URL
    var maxWidth: CGFloat = 220
    var cornerRadius: CGFloat = 8
    var onTap: ((URL, UIView) -> Void)? = nil

    private let placeholderAspectRatio: CGFloat = 0.636  // ~14:9, matches typical landscape photo crop

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        if let onTap {
                            ImageTapCatcher { tapView in
                                onTap(url, tapView)
                            }
                        }
                    }
            case .empty, .failure:
                Color(.clear)
                    .frame(width: maxWidth, height: maxWidth * placeholderAspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}

// MARK: - ImageTapCatcher

/// A transparent UIViewRepresentable overlay that passes itself to the tap handler.
/// Callers use `view.convert(view.bounds, to: nil)` at the moment they need window
/// coordinates — including at dismiss time after a device rotation — so the frame is
/// always current rather than captured once at tap time.
private struct ImageTapCatcher: UIViewRepresentable {
    let onTap: (UIView) -> Void

    func makeUIView(context: Context) -> TapView {
        let view = TapView()
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: TapView, context: Context) {
        uiView.onTap = onTap
    }

    final class TapView: UIView {
        var onTap: ((UIView) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(gesture)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        @objc private func handleTap() {
            onTap?(self)
        }
    }
}

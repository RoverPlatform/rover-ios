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

/// Image loading phase — mirrors AsyncImage.Phase but without @unknown default requirements.
enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// Loads an image from `ImageCache` on cache hit (synchronous), or via URLSession on miss.
/// Stores the decoded UIImage in ImageCache after a successful network fetch.
struct CachedAsyncImage<Content: View>: View {
    let url: URL
    let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase
    @State private var loadedURL: URL?

    init(url: URL, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let cached = ImageCache.shared.image(for: url) {
            _phase = State(initialValue: .success(Image(uiImage: cached)))
            _loadedURL = State(initialValue: url)
        } else {
            _phase = State(initialValue: .empty)
            _loadedURL = State(initialValue: nil)
        }
    }

    var body: some View {
        // ZStack is required: when content returns EmptyView (e.g. only handling .success),
        // SwiftUI cannot attach .task to an empty view and the load never fires. The ZStack
        // ensures there is always a concrete container regardless of what content returns.
        ZStack {
            content(phase)
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        if loadedURL == url, case .success = phase {
            return
        }
        if let uiImage = ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: uiImage))
            loadedURL = url
            return
        }
        do {
            // URLSession.shared is intentional — image URLs are unauthenticated CDN links.
            let (data, _) = try await URLSession.shared.data(from: url)
            let uiImage: UIImage? = await Task.detached(priority: .utility) {
                UIImage(data: data)
            }.value
            guard let uiImage else {
                phase = .failure
                return
            }
            guard !Task.isCancelled else {
                return
            }
            ImageCache.shared.store(uiImage, for: url)
            loadedURL = url
            phase = .success(Image(uiImage: uiImage))
        } catch is CancellationError {
            return
        } catch {
            phase = .failure
        }
    }
}

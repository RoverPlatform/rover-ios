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

import Foundation

/// A canonicalized App Screen identity — the shared currency of the navigation
/// abstraction. `Hashable`/`Identifiable` so it can ride a SwiftUI `NavigationPath`.
package struct AppScreenAddress: Hashable, Identifiable {
    package let url: URL

    package var id: String { url.absoluteString }

    /// Fails when the URL cannot be canonicalized, has no host, or is not an App Screen
    /// path (canonical path must be `/a` or begin with `/a/`).
    package init?(rawURL: URL) {
        guard let canonical = rawURL.canonicalAppScreenURL,
            canonical.host != nil,
            canonical.path == "/a" || canonical.path.hasPrefix("/a/")
        else {
            return nil
        }
        self.url = canonical
    }
}

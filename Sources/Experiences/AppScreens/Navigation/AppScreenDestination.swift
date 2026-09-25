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

/// A `NavigationPath` entry for a pushed App Screen. It carries the **full** target
/// `URLRequest` (headers/method/body preserved), so nothing is lost by riding the path —
/// no side-dictionary. Equality/identity follow the request's URL, so two links to the
/// same template with different queries are distinct path entries (distinct screens). The
/// canonical `address` (query-stripped) is derived once and used only as the
/// warm-session/registry reuse key.
package struct AppScreenDestination: Hashable {
    /// The full request the screen loads — headers, method, body, and query intact.
    package let request: URLRequest
    /// The request's URL, used as the equality/identity key.
    package let url: URL
    /// The canonical (query-stripped) identity used as the warm-session/registry key.
    package let address: AppScreenAddress

    /// Fails when the request has no URL or the URL is not an App Screen path.
    package init?(request: URLRequest) {
        guard let url = request.url, let address = AppScreenAddress(rawURL: url) else {
            return nil
        }
        self.request = request
        self.url = url
        self.address = address
    }

    /// Convenience: a destination for a bare URL (a request with no extra headers/body).
    package init?(url: URL) {
        self.init(request: URLRequest(url: url))
    }

    package static func == (lhs: AppScreenDestination, rhs: AppScreenDestination) -> Bool {
        lhs.url == rhs.url
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

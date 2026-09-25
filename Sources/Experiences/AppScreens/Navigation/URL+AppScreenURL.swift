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

extension URL {
    /// True when `self` is an App Screen entry point: an allowed host (compared
    /// case-insensitively) whose path is the App Screens root `/a` or begins with
    /// `/a/`. Matches the `ExperienceURLClassifier` / `AppScreenAddress` convention,
    /// which both treat a bare `/a` as the App Screens root.
    func isAppScreenURL(allowedHosts: Set<String>) -> Bool {
        guard let host = host?.lowercased() else {
            return false
        }
        let normalizedHosts = Set(allowedHosts.map { $0.lowercased() })
        return normalizedHosts.contains(host) && (path == "/a" || path.hasPrefix("/a/"))
    }

    /// A stable identity for an App Screen: scheme normalized to lowercase and coerced to
    /// `https` (except `http`, preserved for local dev), lowercased host, query and fragment
    /// stripped — so two links to the same screen with different query params (or scheme/host
    /// casing) map to one address.
    var canonicalAppScreenURL: URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme?.lowercased() == "http" ? "http" : "https"
        components.host = components.host?.lowercased()
        components.query = nil
        components.fragment = nil
        return components.url
    }

}

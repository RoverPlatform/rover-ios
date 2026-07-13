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

/// The kind of experience a URL refers to.
package enum ExperienceURLType {
    /// A V3 "App Screens" experience (path prefixed with `/a/`).
    case appScreens
    /// A classic or modern document experience (everything else).
    case document
}

/// Classifies experience URLs so both entry points (`ExperienceViewController`
/// and `ExperienceView`) can route V3 App Screens separately from classic/modern
/// document experiences.
///
/// A `/a/` path prefix denotes a V3 App Screens experience. Matching is
/// component-based (not a string prefix) so paths like `/about` do not produce a
/// false positive, and the query/fragment are left untouched.
package enum ExperienceURLClassifier {
    /// Returns `.appScreens` when `url` is a non-file URL whose first path
    /// component is `a` (i.e. the path begins with `/a/` or is exactly `/a`),
    /// otherwise `.document`.
    package static func classify(_ url: URL) -> ExperienceURLType {
        guard !url.isFileURL else {
            return .document
        }

        let components = url.pathComponents
        guard components.count >= 2, components[1] == "a" else {
            return .document
        }

        return .appScreens
    }
}

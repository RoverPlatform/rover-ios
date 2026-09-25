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

/// The SwiftUI implementation of `AppScreensNavigating`. It holds no view references —
/// every operation forwards to a closure supplied by the SwiftUI layer (which mutates
/// a `NavigationPath` / sheet state). The handlers are `var` so the owning representable
/// can refresh them in `updateUIViewController` when SwiftUI state changes underneath.
@MainActor
package final class AppScreensNavigator: AppScreensNavigating {
    package var pushHandler: (AppScreenAddress, URLRequest?) -> Void
    package var sheetHandler: (AppScreenAddress, URLRequest?, AppScreensToken) -> Void
    package var dismissHandler: () -> Void
    /// Refreshed by the owning representable in `updateUIViewController`;
    /// defaulted rather than an `init` parameter so existing
    /// `AppScreensNavigator(push:presentSheet:dismissRoot:)` call sites keep compiling
    /// unchanged.
    package var websiteHandler: (URL) -> Void = { _ in }

    package init(
        push: @escaping (AppScreenAddress, URLRequest?) -> Void,
        presentSheet: @escaping (AppScreenAddress, URLRequest?, AppScreensToken) -> Void,
        dismissRoot: @escaping () -> Void
    ) {
        self.pushHandler = push
        self.sheetHandler = presentSheet
        self.dismissHandler = dismissRoot
    }

    package func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {
        pushHandler(address, targetRequest)
    }

    package func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {
        sheetHandler(address, targetRequest, sheetToken)
    }

    package func presentWebsite(url: URL) {
        websiteHandler(url)
    }

    package func dismissRoot() {
        dismissHandler()
    }
}

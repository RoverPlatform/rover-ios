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

import XCTest

@testable import RoverExperiences

final class AppScreensOpenHandlerTests: XCTestCase {
    private let url = URL(string: "https://testbench.rover.io/some/target")!

    func testEmbeddedReturnsNilSoCoordinatorHandlesOpen() {
        let handler = makeAppScreensOpenExternalURLHandler(
            isModal: false,
            dismiss: { _ in XCTFail("embedded must not dismiss") },
            open: { _ in XCTFail("embedded must not open via this handler") }
        )
        XCTAssertNil(handler, "embedded (non-modal) must register no owner handler")
    }

    func testModalDismissFalseOpensInPlaceWithoutDismissing() {
        var opened: URL?
        var dismissCalled = false
        let handler = makeAppScreensOpenExternalURLHandler(
            isModal: true,
            dismiss: { _ in dismissCalled = true },
            open: { opened = $0 }
        )
        handler?(url, false)
        XCTAssertEqual(opened, url)
        XCTAssertFalse(dismissCalled, "dismiss:false must open in place, never dismiss")
    }

    func testModalDismissTrueDismissesThenOpensInCompletion() {
        var opened: URL?
        var capturedCompletion: (() -> Void)?
        let handler = makeAppScreensOpenExternalURLHandler(
            isModal: true,
            dismiss: { completion in capturedCompletion = completion },
            open: { opened = $0 }
        )
        handler?(url, true)
        XCTAssertNil(opened, "must NOT open until the dismissal completes")
        XCTAssertNotNil(capturedCompletion, "dismiss:true must invoke dismiss")
        capturedCompletion?()
        XCTAssertEqual(opened, url, "open must fire in the dismiss completion")
    }
}

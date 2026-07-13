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

import Combine
import UIKit
import XCTest

@testable import RoverNotifications

final class ScrollCoordinatorBridgeTests: XCTestCase {

    /// Validates the bridge wiring end-to-end: when a new reply arrives while the UIKit
    /// ScrollCoordinator is already at the bottom, the event flows through the bridge sink
    /// into the SwiftUI ConversationScrollCoordinator's reachedBottom publisher.
    ///
    /// This is the critical "already at bottom" path that .onChange(of: isAtBottom) misses —
    /// because isAtBottom stays true, no state change fires.
    @MainActor
    func testBridgeForwardsReachedBottomFromDidReceiveNewReplies() async {
        // 1. Create a zero-content UICollectionView and a UIKit ScrollCoordinator wrapping it.
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let scrollCoordinator = ScrollCoordinator(collectionView: cv)

        // 2. Drive isAtBottom = true on the UIKit coordinator BEFORE wiring the bridge.
        //    Zero-content CV: visibleBottom = 844 >= contentSize.height(0) - threshold(-40).
        //    The bridge is installed afterwards so this synchronous send() is never forwarded.
        scrollCoordinator.syncScrollState()
        XCTAssertTrue(scrollCoordinator.isAtBottom)

        // 3. Create a SwiftUI coordinator and wire the bridge — same code as makeUIViewController.
        //    Installing the cancellable after syncScrollState ensures the step-2 event is
        //    never forwarded, even though .receive(on: DispatchQueue.main) is asynchronous.
        let swiftUICoordinator = ConversationScrollCoordinator()
        swiftUICoordinator.reachedBottomCancellable =
            scrollCoordinator.reachedBottom
            .receive(on: DispatchQueue.main)
            .sink { [weak swiftUICoordinator] in
                swiftUICoordinator?.reachedBottom.send()
            }

        // 4. Install the spy sink on the SwiftUI coordinator.
        //    Use XCTestExpectation because .receive(on: DispatchQueue.main) makes the bridge
        //    delivery asynchronous — asserting immediately after send() would race the delivery.
        let expectation = expectation(description: "reachedBottom event received through bridge")
        var eventCount = 0
        let cancellable = swiftUICoordinator.reachedBottom.sink {
            eventCount += 1
            if eventCount == 1 { expectation.fulfill() }
        }

        // 5. Simulate a new reply arriving while already at the bottom.
        scrollCoordinator.didReceiveNewReplies(count: 1)

        // 6. Wait for the async bridge delivery, then assert exactly one event arrived.
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(
            eventCount,
            1,
            "Bridge must forward reachedBottom from UIKit ScrollCoordinator to SwiftUI coordinator"
        )
        cancellable.cancel()
    }
}

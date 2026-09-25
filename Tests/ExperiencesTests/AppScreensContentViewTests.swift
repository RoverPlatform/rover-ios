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
import XCTest

@testable import RoverExperiences

@MainActor
final class AppScreensContentViewTests: XCTestCase {
    private final class PathModel: ObservableObject {
        @Published var path = NavigationPath()
    }

    private struct TestHost: View {
        @ObservedObject var model: PathModel
        let registry: AppScreensPageRegistry
        let rootURL: URL
        let makeScreen: (AppScreensPageRequest) -> UIViewController

        var body: some View {
            NavigationStack(path: $model.path) {
                AppScreensContentView(
                    rootURL: rootURL,
                    path: $model.path,
                    registry: registry,
                    makeScreen: makeScreen,
                    sheetCollapse: AppScreensSheetCollapseCoordinator()
                )
            }
        }
    }

    private func url(_ path: String) -> URL {
        URL(string: "https://testbench.rover.io/a/\(path)")!
    }

    private func address(_ path: String) -> AppScreenAddress {
        AppScreenAddress(rawURL: url(path))!
    }

    /// Spins the main run loop in small increments until `predicate` holds or the timeout
    /// elapses — so SwiftUI's make/dismantle transactions settle without a fixed sleep.
    /// Returns the final value of `predicate`.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    func testDismantleFiresForEveryRemovedDestinationOnFullReset() {
        let registry = AppScreensPageRegistry()
        let model = PathModel()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: TestHost(
                model: model,
                registry: registry,
                rootURL: url("home"),
                makeScreen: { _ in UIViewController() }
            )
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let detailA = address("detail-a")
        let detailB = address("detail-b")

        model.path.append(AppScreenDestination(url: url("detail-a"))!)
        XCTAssertTrue(
            waitUntil { registry.isOnStack(detailA) },
            "detail-a should be created and on the stack after pushing it"
        )
        model.path.append(AppScreenDestination(url: url("detail-b"))!)
        XCTAssertTrue(
            waitUntil { registry.isOnStack(detailA) && registry.isOnStack(detailB) },
            "both screens should be created and on the stack after pushing"
        )

        // Full reset — the behaviour a Hub-driven navigation performs.
        model.path = NavigationPath()
        XCTAssertTrue(
            waitUntil { !registry.isOnStack(detailA) && !registry.isOnStack(detailB) },
            "dismantle must fire for BOTH the intermediate and the top on a full reset"
        )
        XCTAssertTrue(registry.isWarm(detailA), "detail-a should be kept warm after reset")
        XCTAssertTrue(registry.isWarm(detailB), "detail-b should be kept warm after reset")
    }

    func testPushedScreenReceivesQueryBearingRequest() {
        let registry = AppScreensPageRegistry()
        let model = PathModel()
        var receivedRequests: [URLRequest?] = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: TestHost(
                model: model,
                registry: registry,
                rootURL: url("home"),
                makeScreen: { screenRequest in
                    receivedRequests.append(screenRequest.targetRequest)
                    return UIViewController()
                }
            )
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        model.path.append(AppScreenDestination(url: url("detail?id=42"))!)
        let carriedQuery = waitUntil {
            receivedRequests.contains { $0?.url?.query?.contains("id=42") ?? false }
        }
        XCTAssertTrue(carriedQuery, "the pushed screen must receive a request carrying the id=42 query")
    }
}

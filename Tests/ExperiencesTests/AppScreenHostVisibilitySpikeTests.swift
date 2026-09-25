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
final class AppScreenHostVisibilitySpikeTests: XCTestCase {
    private final class ProbeViewController: UIViewController {
        var appeared = 0
        var disappeared = 0
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appeared += 1
        }
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            disappeared += 1
        }
    }
    private struct Probe: UIViewControllerRepresentable {
        let make: () -> UIViewController
        func makeUIViewController(context: Context) -> UIViewController { make() }
        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    }
    private final class PathModel: ObservableObject { @Published var path = NavigationPath() }
    private struct Host: View {
        @ObservedObject var model: PathModel
        let root: () -> UIViewController
        let detail: () -> UIViewController
        var body: some View {
            NavigationStack(path: $model.path) {
                Probe(make: root).ignoresSafeArea()
                    .navigationDestination(for: Int.self) { _ in Probe(make: detail).ignoresSafeArea() }
            }
        }
    }
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        return predicate()
    }
    func testChildVCReceivesAppearanceCallbacksUnderNavigationStack() {
        let model = PathModel()
        let rootProbe = ProbeViewController()
        let detailProbe = ProbeViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: Host(model: model, root: { rootProbe }, detail: { detailProbe })
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertTrue(waitUntil { rootProbe.appeared >= 1 }, "root child VC should appear")
        model.path.append(1)
        XCTAssertTrue(waitUntil { detailProbe.appeared >= 1 }, "pushed child VC should appear")
        XCTAssertTrue(waitUntil { rootProbe.disappeared >= 1 }, "root child VC should disappear when covered")
        model.path = NavigationPath()
        XCTAssertTrue(waitUntil { detailProbe.disappeared >= 1 }, "popped child VC should disappear")
        XCTAssertTrue(waitUntil { rootProbe.appeared >= 2 }, "root child VC should re-appear after pop")
    }
}

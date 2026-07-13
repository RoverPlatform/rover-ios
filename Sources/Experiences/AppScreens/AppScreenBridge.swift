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
import WebKit

/// The message-handler name the web runtime posts to via
/// `window.webkit.messageHandlers.roverAppScreens.postMessage(...)`.
let appScreensMessageHandlerName = "roverAppScreens"

/// A message posted up from the web runtime through the `roverAppScreens`
/// message handler.
///
/// This is decoded defensively from the raw `WKScriptMessage.body` (a JSON value
/// bridged to `Any`) rather than through a `Codable` envelope: the `optimisticData`
/// payload is opaque JSON authored by the screen that must cross to the runtime verbatim,
/// so it is re-serialized once to a JSON `String` (never modelled).
enum AppScreenMessage: Equatable {
    /// The runtime booted and defined `window.RoverAppScreens`.
    case loaded
    /// A `[data-rover-link]` element was tapped. `optimisticDataJSON` is the element's
    /// pre-serialized optimistic-data payload (a JSON string), or `nil` when absent.
    /// `transition` is the link's optional `data-rover-transition` intent; `nil`
    /// means the field was absent or unrecognized and downstream treats it as push.
    case navigate(href: String, optimisticDataJSON: String?, transition: AppScreenTransition?)
    /// Distinct link targets discovered after hydration (prewarm hints), in DOM
    /// order.
    case links(hrefs: [String])

    /// Defensively decodes a message body. Returns `nil` for unknown or malformed
    /// payloads (which the caller logs and ignores).
    init?(body: Any) {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else {
            return nil
        }

        switch type {
        case "loaded":
            self = .loaded
        case "navigate":
            guard let href = dict["href"] as? String else {
                return nil
            }
            // Only the exact strings "sheet"/"push" map to a transition; any other
            // value (or an absent field) decodes to `nil`, which every downstream
            // path treats as push per the navigate contract.
            let transition = (dict["transition"] as? String).flatMap(AppScreenTransition.init(rawValue:))
            self = .navigate(
                href: href,
                optimisticDataJSON: Self.jsonString(from: dict["optimisticData"]),
                transition: transition
            )
        case "links":
            let hrefs = (dict["hrefs"] as? [Any])?.compactMap { $0 as? String } ?? []
            self = .links(hrefs: hrefs)
        default:
            return nil
        }
    }

    /// Re-serializes an opaque JSON value back to a JSON `String` so it can cross
    /// to the runtime verbatim. Returns `nil` for a missing/`NSNull` value or if
    /// the value is not serializable.
    private static func jsonString(from value: Any?) -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }
}

/// How a `navigate` target enters the stack. Carried as the link's optional
/// `data-rover-transition` attribute (the flows prototype passed the equivalent as
/// a query parameter; App Screens moved it onto the element). Absent or
/// unrecognized values decode to `nil`, which every navigation path treats as
/// `push` — sheet presentation is opt-in only.
enum AppScreenTransition: String {
    case push
    case sheet
}

/// Weakly forwards `WKScriptMessageHandler` callbacks so the user-content
/// controller (retained strongly by every configuration) does not keep the real
/// handler — and, transitively, the navigator and its web views — alive.
final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler? = nil) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

/// Thrown by ``withTimeout(seconds:_:)`` when the wrapped work does not finish in
/// time. App Screens bounds every network/runtime await so a stalled load can
/// never present an infinite skeleton.
struct AppScreenTimeoutError: LocalizedError {
    let seconds: Double
    var errorDescription: String? {
        "App Screens operation timed out after \(seconds)s"
    }
}

/// Races `body` against a timeout: returns `body`'s value if it finishes first,
/// otherwise throws ``AppScreenTimeoutError``. Structured — the loser is
/// cancelled before returning.
func withTimeout<T: Sendable>(
    seconds: Double,
    _ body: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AppScreenTimeoutError(seconds: seconds)
        }

        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw AppScreenTimeoutError(seconds: seconds)
        }
        return result
    }
}

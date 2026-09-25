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

@testable import RoverNotifications

/// Covers what the conversation detail screen shows, which is a decision over the store and one
/// load state rather than anything the SwiftUI lifecycle does.
final class ConversationDetailPhaseTests: XCTestCase {

    private let everyLoadState: [ConversationLoadState] = [.idle, .fetching, .notFound, .showing]

    // MARK: The invariant

    /// The rule the screen must never break, over every load state.
    ///
    /// `.thread` renders the collection view AND the reply composer, so reaching it without a
    /// conversation offers a reply into a thread that is not in the store. Asserted over every
    /// load state, so it holds on the data rather than on the timing of a fetch.
    func testAbsentConversationNeverShowsTheThread() {
        for load in everyLoadState {
            XCTAssertNotEqual(
                ConversationDetailPhase(hasConversation: false, load: load),
                .thread,
                "no conversation must never render the thread (load: \(load))"
            )
        }
    }

    /// The store is the answer whenever it has one, whatever the load state was left on. The
    /// screen reacts to an arrival in `ConversationDetailView`'s `onChange`; this pins only that
    /// the content follows the data.
    func testPresentConversationAlwaysShowsTheThread() {
        for load in everyLoadState {
            XCTAssertEqual(
                ConversationDetailPhase(hasConversation: true, load: load),
                .thread,
                "a conversation in the store must render the thread (load: \(load))"
            )
        }
    }

    // MARK: The regression

    /// A fetch that finishes and finds nothing must show as not found in the screen's own state,
    /// not only in an alert, which a transition in flight can drop and never re-present.
    func testReportedMissingIsNotFound() {
        XCTAssertEqual(ConversationDetailPhase(hasConversation: false, load: .notFound), .notFound)
    }

    // MARK: Waiting

    /// Nothing has reported yet. Not an error, so it must not claim one, and not a thread either,
    /// which would offer a reply into a conversation that may not exist.
    func testAbsentAndIdleIsLoading() {
        XCTAssertEqual(ConversationDetailPhase(hasConversation: false, load: .idle), .loading)
    }

    /// A retry supersedes the previous attempt's verdict in the load state itself, so there is no
    /// "fetching but also not found" for this decision to have to rank.
    func testAbsentAndFetchingIsLoading() {
        XCTAssertEqual(ConversationDetailPhase(hasConversation: false, load: .fetching), .loading)
    }
}

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

/// What the conversation detail screen shows, derived from the data rather than from which
/// callback ran last.
///
/// Lives outside the view so the decision can be tested without presenting anything, the SwiftUI
/// lifecycle around it not being reliably testable headlessly.
enum ConversationDetailPhase: Equatable {
    /// Waiting on the conversation: nothing has reported yet, or a fetch is running.
    case loading
    /// The conversation is in the store. The only phase that renders the reply composer.
    case thread
    /// The conversation has been reported missing.
    case notFound

    /// A missing conversation can never resolve to `.thread`, whatever the load state says.
    /// Rendering the thread also renders the composer, and a reply must not be typed into a
    /// conversation that is not in the store.
    init(hasConversation: Bool, load: ConversationLoadState) {
        guard !hasConversation else {
            // A conversation that has arrived wins over a load state left behind by an earlier
            // attempt: the store is the answer, and the screen reacts to its arrival elsewhere.
            self = .thread
            return
        }
        self = load == .notFound ? .notFound : .loading
    }
}

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

/// Shown in place of the thread when the conversation is nowhere to be found.
///
/// The screen's durable answer to that outcome. The alert raised alongside it says the same
/// thing, but can be dropped when it lands mid-transition, and this cannot.
///
/// Matches the thread's own empty state so the two read as the same screen, not an error page.
struct ConversationNotFoundView: View {
    let onGoBack: () -> Void

    /// Identifiers sit on the leaves, not on the stack. SwiftUI propagates a container's
    /// identifier to every child, which would leave two elements answering to one name and make
    /// any `exists` check on it an ambiguous match.
    var body: some View {
        VStack(spacing: 16) {
            Text("This conversation could not be found.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("rover.hub.conversationNotFound.message")
            Button("Go back", action: onGoBack)
                .font(.body)
                .accessibilityIdentifier("rover.hub.conversationNotFound.goBack")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

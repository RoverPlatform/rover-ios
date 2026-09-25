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

/// Tokenised search with real avatar chips, degrading gracefully.
///
/// The primary path keeps a plain `.searchable(text:)` field and hands token
/// ownership to `HubSearchTokenBridge`, whose `UISearchToken(icon:)` chips can
/// carry the subscription logo or sender avatar. If the bridge cannot find the
/// backing search field, the modifier permanently falls back to the
/// SwiftUI-managed token binding for this view's lifetime — the chip is then a
/// plain SF Symbol (the system re-renders token label content itself and
/// stretches custom image views regardless of framing or clipping), but a
/// token is always visible whenever one is filtering.
struct SearchTokenModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var searchTokens: [HubSearchToken]

    @State private var bridgeFailed = false

    func body(content: Content) -> some View {
        if bridgeFailed {
            content
                .searchable(text: $searchText, tokens: $searchTokens) { token in
                    Label(token.name, systemImage: token.systemImage)
                }
        } else {
            content
                .searchable(text: $searchText)
                .background(
                    HubSearchTokenBridge(
                        token: searchTokens.first,
                        onTokenRemoved: { searchTokens = [] },
                        onAttachFailure: { bridgeFailed = true }
                    )
                )
        }
    }
}

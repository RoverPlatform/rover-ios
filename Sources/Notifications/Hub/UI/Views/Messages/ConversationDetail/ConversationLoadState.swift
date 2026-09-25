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

/// How far the conversation detail screen has got in obtaining its conversation.
///
/// One value rather than a flag per outcome, so the combinations that mean nothing cannot be
/// written down: fetching while already reported missing, missing while already showing.
enum ConversationLoadState: Equatable {
    /// The screen is not live: it has not appeared yet, or it has disappeared and been torn down.
    /// Load-bearing rather than merely an initial value, because it is how the view knows an
    /// arriving conversation must not restart a lifecycle offscreen.
    case idle
    /// An on-demand fetch is in flight. Supersedes a previous `notFound`: the retry may succeed,
    /// and the screen must not claim an error the data no longer supports.
    case fetching
    /// The attempt finished and the conversation is nowhere to be found: either the fetch came
    /// back empty, or there was no sync service to fetch with.
    case notFound
    /// The screen has started: the conversation is reported displayed and its reply sync runs.
    case showing
}

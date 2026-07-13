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

@testable import RoverAppExtensions

final class ConversationNotificationPreviewTextExtractorTests: XCTestCase {
    func testReturnsFirstNonEmptyTextBlock() {
        let blocks: [ConversationPushPayload.RoverPayload.Reply.ContentBlock] = [
            .init(type: "image", text: nil, url: URL(string: "https://example.com/image.jpg")),
            .init(type: "text", text: "Hi, I have a question", url: nil),
            .init(type: "text", text: "ignored", url: nil),
        ]

        XCTAssertEqual(
            ConversationNotificationPreviewTextExtractor.previewText(from: blocks),
            "Hi, I have a question"
        )
    }

    func testReturnsNilWhenNoTextBlockExists() {
        let blocks: [ConversationPushPayload.RoverPayload.Reply.ContentBlock] = [
            .init(type: "image", text: nil, url: URL(string: "https://example.com/image.jpg"))
        ]

        XCTAssertNil(ConversationNotificationPreviewTextExtractor.previewText(from: blocks))
    }

    func testSkipsWhitespaceOnlyTextBlocks() {
        let blocks: [ConversationPushPayload.RoverPayload.Reply.ContentBlock] = [
            .init(type: "text", text: "  \n ", url: nil),
            .init(type: "text", text: "Hi, I have a question", url: nil),
        ]

        XCTAssertEqual(
            ConversationNotificationPreviewTextExtractor.previewText(from: blocks),
            "Hi, I have a question"
        )
    }

    func testTrimsNonEmptyTextBlock() {
        let blocks: [ConversationPushPayload.RoverPayload.Reply.ContentBlock] = [
            .init(type: "text", text: "  Hello world  \n", url: nil)
        ]

        XCTAssertEqual(
            ConversationNotificationPreviewTextExtractor.previewText(from: blocks),
            "Hello world"
        )
    }
}

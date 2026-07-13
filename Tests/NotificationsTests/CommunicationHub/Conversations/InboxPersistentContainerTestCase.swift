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

class InboxPersistentContainerTestCase: XCTestCase {
    var container: InboxPersistentContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = InboxPersistentContainer(storage: .inMemory)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    func assertViewContextSave(
        _ failureMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try container.viewContext.save()
        } catch {
            XCTFail("\(failureMessage): \(error)", file: file, line: line)
        }
    }

    @MainActor
    func attachTextBlock(_ text: String, to reply: Reply, sortOrder: Int16 = 0) {
        let contentBlock = ReplyContentBlock(context: container.viewContext)
        contentBlock.type = "text"
        contentBlock.text = text
        contentBlock.sortOrder = sortOrder
        contentBlock.reply = reply
    }
}

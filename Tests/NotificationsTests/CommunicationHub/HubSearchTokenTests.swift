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

final class HubSearchTokenTests: XCTestCase {
    func testIDsAreStableAndDistinctAcrossCases() {
        let subscription = HubSearchToken.subscription(id: "abc", name: "News", logoURL: nil)
        let sender = HubSearchToken.sender(participantID: "abc", name: "News", avatarURL: nil)
        XCTAssertEqual(subscription.id, "sub:abc")
        XCTAssertEqual(sender.id, "sender:abc")
        XCTAssertNotEqual(subscription.id, sender.id)
    }

    func testNameAndSystemImage() {
        let subscription = HubSearchToken.subscription(id: "s1", name: "News Daily", logoURL: nil)
        let sender = HubSearchToken.sender(participantID: "p1", name: "Alice Johnson", avatarURL: nil)
        XCTAssertEqual(subscription.name, "News Daily")
        XCTAssertEqual(subscription.systemImage, "newspaper.circle.fill")
        XCTAssertEqual(sender.name, "Alice Johnson")
        XCTAssertEqual(sender.systemImage, "person.circle.fill")
    }

    func testImageURL() {
        let logo = URL(string: "https://example.com/logo.png")
        let avatar = URL(string: "https://example.com/avatar.png")
        XCTAssertEqual(
            HubSearchToken.subscription(id: "s1", name: "News", logoURL: logo).imageURL,
            logo
        )
        XCTAssertEqual(
            HubSearchToken.sender(participantID: "p1", name: "Alice", avatarURL: avatar).imageURL,
            avatar
        )
        XCTAssertNil(HubSearchToken.subscription(id: "s1", name: "News", logoURL: nil).imageURL)
    }
}

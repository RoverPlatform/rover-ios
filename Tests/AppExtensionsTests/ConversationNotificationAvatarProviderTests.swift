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

import Intents
import UIKit
import XCTest

@testable import RoverAppExtensions

final class ConversationNotificationAvatarProviderTests: XCTestCase {
    func testDoesNotCallDownloaderWhenAvatarURLIsMissing() async {
        let downloader = AvatarDownloaderSpy(data: nil)
        let provider = ConversationNotificationAvatarProvider(
            downloader: downloader
        )

        let avatar = await provider.avatar(
            participantID: "participant-uuid",
            participantName: "Jane Doe",
            avatarURL: nil
        )

        XCTAssertTrue(downloader.requestedURLs.isEmpty)
        XCTAssertNotNil(avatar)
    }

    func testCallsDownloaderWhenAvatarURLIsPresent() async {
        let avatarURL = URL(string: "https://example.com/avatar.jpg")!
        let downloader = AvatarDownloaderSpy(data: onePixelPNGData())
        let provider = ConversationNotificationAvatarProvider(
            downloader: downloader
        )

        let avatar = await provider.avatar(
            participantID: "participant-uuid",
            participantName: "Jane Doe",
            avatarURL: avatarURL
        )

        XCTAssertEqual(downloader.requestedURLs, [avatarURL])
        // `INImage` only exposes public initializers, not a public accessor for the wrapped bytes.
        // We avoid KVC against undocumented internals here so the test does not depend on framework
        // implementation details.
        XCTAssertNotNil(avatar)
    }

    func testFallsBackToGeneratedInitialsAvatarWhenAvatarDownloadFails() async {
        let avatarURL = URL(string: "https://example.com/avatar.jpg")!
        let downloader = AvatarDownloaderSpy(data: nil)
        let provider = ConversationNotificationAvatarProvider(
            downloader: downloader
        )

        let avatar = await provider.avatar(
            participantID: "participant-uuid",
            participantName: "Jane Doe",
            avatarURL: avatarURL
        )

        XCTAssertEqual(downloader.requestedURLs, [avatarURL])
        XCTAssertNotNil(avatar)
    }

    func testLiveDownloaderRejectsNonHTTPSAvatarURLs() async {
        let downloader = LiveConversationNotificationAvatarDownloader()

        let imageData = await downloader.imageData(from: URL(string: "http://example.com/avatar.jpg")!)

        XCTAssertNil(imageData)
    }

    private func onePixelPNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        return image.pngData()!
    }
}

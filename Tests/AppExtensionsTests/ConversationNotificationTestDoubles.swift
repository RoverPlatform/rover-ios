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
import UserNotifications

@testable import RoverAppExtensions

struct AvatarDownloaderStub: ConversationNotificationAvatarDownloading {
    let data: Data?

    func imageData(from url: URL) async -> Data? {
        data
    }
}

struct AvatarLoaderStub: ConversationNotificationAvatarLoading {
    let image: INImage?

    func avatar(
        participantID: String,
        participantName: String,
        avatarURL: URL?
    ) async -> INImage? {
        image
    }
}

final class AvatarLoaderSpy: ConversationNotificationAvatarLoading {
    private(set) var receivedCalls: [(participantID: String, participantName: String, avatarURL: URL?)] = []
    let image: INImage?

    init(image: INImage?) {
        self.image = image
    }

    func avatar(
        participantID: String,
        participantName: String,
        avatarURL: URL?
    ) async -> INImage? {
        receivedCalls.append((participantID: participantID, participantName: participantName, avatarURL: avatarURL))
        return image
    }
}

final class AvatarDownloaderSpy: ConversationNotificationAvatarDownloading {
    private(set) var requestedURLs: [URL] = []
    let data: Data?

    init(data: Data?) {
        self.data = data
    }

    func imageData(from url: URL) async -> Data? {
        requestedURLs.append(url)
        return data
    }
}

final class DonorSpy: ConversationNotificationDonating {
    private(set) var donatedInteractions: [INInteraction] = []

    func donate(_ interaction: INInteraction) async throws {
        donatedInteractions.append(interaction)
    }
}

struct UpdaterStub: ConversationNotificationContentUpdating {
    let content: UNNotificationContent

    func updatedContent(
        from content: UNNotificationContent,
        using intent: INSendMessageIntent
    ) throws -> UNNotificationContent {
        self.content
    }
}

final class UpdaterSpy: ConversationNotificationContentUpdating {
    private(set) var receivedThreadIdentifiers: [String] = []
    let content: UNNotificationContent

    init(content: UNNotificationContent) {
        self.content = content
    }

    func updatedContent(
        from content: UNNotificationContent,
        using intent: INSendMessageIntent
    ) throws -> UNNotificationContent {
        receivedThreadIdentifiers.append(content.threadIdentifier)
        return self.content
    }
}

struct ThrowingUpdater: ConversationNotificationContentUpdating {
    enum StubError: Error {
        case failed
    }

    func updatedContent(
        from content: UNNotificationContent,
        using intent: INSendMessageIntent
    ) throws -> UNNotificationContent {
        throw StubError.failed
    }
}

struct ConversationEnricherSpy: ConversationNotificationEnriching {
    let result: UNNotificationContent?

    func enrichedContent(
        payload: ConversationPushPayload,
        from content: UNMutableNotificationContent
    ) async -> UNNotificationContent? {
        result
    }
}

func stubUpdatedContent() -> UNNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "Jane Doe"
    content.body = "Hi, I have a question"
    return content
}

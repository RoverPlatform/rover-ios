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
import Intents
import UIKit
import os

private let avatarLogger = Logger(subsystem: "io.rover.sdk", category: "NotificationExtension")

/// Abstracts remote avatar fetching so the communication-notification path can be tested without
/// real network traffic.
protocol ConversationNotificationAvatarDownloading {
    func imageData(from url: URL) async -> Data?
}

/// Produces the sender image Apple will associate with the `INPerson` in the donated intent.
///
/// The live implementation prefers the remote avatar URL from the payload, but always falls back
/// to a locally rendered initials avatar so we do not regress to the app icon when the backend
/// has not yet supplied sender images.
protocol ConversationNotificationAvatarLoading {
    func avatar(
        participantID: String,
        participantName: String,
        avatarURL: URL?
    ) async -> INImage?
}

/// Live avatar loader used by the notification service extension.
///
/// This type hides two concerns:
/// 1. Asynchronous avatar download via `URLSession`.
/// 2. Local initials-avatar generation when the payload does not include a usable image URL.
struct ConversationNotificationAvatarProvider: ConversationNotificationAvatarLoading {
    let downloader: ConversationNotificationAvatarDownloading

    func avatar(
        participantID: String,
        participantName: String,
        avatarURL: URL?
    ) async -> INImage? {
        guard let avatarURL else {
            avatarLogger.debug(
                "no avatar URL for participant \(participantID, privacy: .private), generating initials avatar"
            )
            return generatedAvatar(participantID: participantID, participantName: participantName)
        }

        guard let imageData = await downloader.imageData(from: avatarURL) else {
            avatarLogger.debug(
                "avatar download unavailable for participant \(participantID, privacy: .private), falling back to initials avatar from \(avatarURL.absoluteString, privacy: .private)"
            )
            return generatedAvatar(participantID: participantID, participantName: participantName)
        }

        avatarLogger.debug(
            "loaded avatar data for participant \(participantID, privacy: .private) from \(avatarURL.absoluteString, privacy: .private)"
        )
        return INImage(imageData: imageData)
    }

    private func generatedAvatar(
        participantID: String,
        participantName: String
    ) -> INImage? {
        // Keep the fallback intentionally simple and deterministic so the same participant gets
        // the same color even across process launches.
        let letter =
            participantName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
            .map { String($0).uppercased() } ?? "?"

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96))
        let image = renderer.image { _ in
            UIColor.systemGray.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 96, height: 96)).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let text = NSAttributedString(string: letter, attributes: attributes)
            let size = text.size()
            let rect = CGRect(
                x: (96 - size.width) / 2,
                y: (96 - size.height) / 2,
                width: size.width,
                height: size.height
            )
            text.draw(in: rect)
        }

        guard let imageData = image.pngData() else {
            return nil
        }

        return INImage(imageData: imageData)
    }
}

/// Production downloader for remote participant avatars.
///
/// The extension uses async `URLSession` rather than synchronous `Data(contentsOf:)` so it fits
/// naturally with the rest of the async communication-enrichment pipeline.
struct LiveConversationNotificationAvatarDownloader: ConversationNotificationAvatarDownloading {
    func imageData(from url: URL) async -> Data? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            avatarLogger.debug(
                "ignoring non-HTTPS avatar URL for \(url.absoluteString, privacy: .private)"
            )
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                avatarLogger.debug(
                    "avatar download failed with status \(statusCode, privacy: .public) for \(url.absoluteString, privacy: .private)"
                )
                return nil
            }

            return data
        } catch {
            avatarLogger.error(
                "avatar download threw error for \(url.absoluteString, privacy: .private): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}

extension ConversationNotificationAvatarProvider {
    static let live = ConversationNotificationAvatarProvider(
        downloader: LiveConversationNotificationAvatarDownloader()
    )
}

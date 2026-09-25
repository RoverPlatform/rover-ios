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

import CoreData
import Foundation

/// Pure filtering and suggestion logic for the Hub messages search.
/// Kept free of view state so it can be unit tested directly.
enum HubSearchFilter {
    /// Filters the merged, sorted list of hub items by free text and an
    /// optional token. A subscription token narrows to that subscription's
    /// posts; a sender token narrows to conversations involving that
    /// participant. Any search text then matches within the narrowed set.
    static func filter(
        items: [HubItem],
        searchText: String,
        token: HubSearchToken?
    ) -> [HubItem] {
        switch token {
        case .none:
            guard !searchText.isEmpty else { return items }
            return items.filter { matchesFreeText($0, searchText: searchText) }
        case .subscription(let subscriptionID, _, _):
            return items.filter { item in
                guard case .post(let post) = item,
                    post.subscription?.id == subscriptionID
                else { return false }
                guard !searchText.isEmpty else { return true }
                return post.subject?.localizedCaseInsensitiveContains(searchText) == true
                    || post.previewText?.localizedCaseInsensitiveContains(searchText) == true
            }
        case .sender(let participantID, _, _):
            return items.filter { item in
                guard case .conversation(let conversation) = item,
                    participants(of: conversation).contains(where: { $0.id == participantID })
                else { return false }
                guard !searchText.isEmpty else { return true }
                return conversation.subject?.localizedCaseInsensitiveContains(searchText) == true
                    || conversation.lastReplyPreview?
                        .localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    /// Builds token suggestions from the currently loaded items so every
    /// offered token is guaranteed to produce at least one result.
    /// Placeholder subscriptions (nil/empty name) and empty ids are skipped.
    static func suggestions(items: [HubItem], searchText: String) -> [HubSearchToken] {
        guard !searchText.isEmpty else { return [] }
        var subscriptionsByID: [String: (name: String, logoURL: URL?)] = [:]
        var participantsByID: [String: (name: String, avatarURL: URL?)] = [:]

        for item in items {
            switch item {
            case .post(let post):
                guard
                    let subscription = post.subscription,
                    let subscriptionID = subscription.id, !subscriptionID.isEmpty,
                    let name = subscription.name, !name.isEmpty,
                    name.localizedCaseInsensitiveContains(searchText)
                else { continue }
                subscriptionsByID[subscriptionID] = (name: name, logoURL: subscription.logoURL)
            case .conversation(let conversation):
                for participant in participants(of: conversation) {
                    guard
                        let participantID = participant.id, !participantID.isEmpty,
                        let name = participant.name, !name.isEmpty,
                        name.localizedCaseInsensitiveContains(searchText)
                    else { continue }
                    participantsByID[participantID] = (
                        name: name,
                        avatarURL: participant.avatarURL.flatMap(URL.init(string:))
                    )
                }
            }
        }

        let subscriptionTokens =
            subscriptionsByID
            .map {
                HubSearchToken.subscription(
                    id: $0.key,
                    name: $0.value.name,
                    logoURL: $0.value.logoURL
                )
            }
            .sorted(by: isOrderedBefore)
        let senderTokens =
            participantsByID
            .map {
                HubSearchToken.sender(
                    participantID: $0.key,
                    name: $0.value.name,
                    avatarURL: $0.value.avatarURL
                )
            }
            .sorted(by: isOrderedBefore)
        return subscriptionTokens + senderTokens
    }

    private static func isOrderedBefore(_ lhs: HubSearchToken, _ rhs: HubSearchToken) -> Bool {
        switch lhs.name.localizedStandardCompare(rhs.name) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return lhs.id < rhs.id
        }
    }

    private static func matchesFreeText(_ item: HubItem, searchText: String) -> Bool {
        switch item {
        case .post(let post):
            return post.subject?.localizedCaseInsensitiveContains(searchText) == true
                || post.previewText?.localizedCaseInsensitiveContains(searchText) == true
                || post.subscription?.name?.localizedCaseInsensitiveContains(searchText) == true
        case .conversation(let conversation):
            guard
                conversation.subject?.localizedCaseInsensitiveContains(searchText) != true,
                conversation.lastReplyPreview?.localizedCaseInsensitiveContains(searchText) != true
            else { return true }
            return participants(of: conversation)
                .contains { $0.name?.localizedCaseInsensitiveContains(searchText) == true }
        }
    }

    private static func participants(of conversation: Conversation) -> [Participant] {
        (conversation.participants as? Set<Participant>).map(Array.init) ?? []
    }
}

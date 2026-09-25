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
import XCTest

@testable import RoverNotifications

final class HubSearchFilterTests: InboxPersistentContainerTestCase {
    // MARK: - Fixtures

    @MainActor
    func makeSubscription(id: String, name: String?, logoURL: URL? = nil) -> Subscription {
        let subscription = Subscription(context: container.viewContext)
        subscription.id = id
        subscription.name = name
        subscription.logoURL = logoURL
        return subscription
    }

    @MainActor
    func makePost(
        subject: String,
        previewText: String? = nil,
        subscription: Subscription? = nil,
        receivedAt: Date = Date()
    ) -> Post {
        let post = Post(context: container.viewContext)
        post.id = UUID()
        post.subject = subject
        post.previewText = previewText
        post.receivedAt = receivedAt
        post.subscription = subscription
        return post
    }

    @MainActor
    func makeParticipant(id: String, name: String?, avatarURL: String? = nil) -> Participant {
        let participant = Participant(context: container.viewContext)
        participant.id = id
        participant.name = name
        participant.avatarURL = avatarURL
        return participant
    }

    @MainActor
    func makeConversation(
        subject: String?,
        lastReplyPreview: String? = nil,
        participants: [Participant] = []
    ) -> Conversation {
        let conversation = Conversation(context: container.viewContext)
        conversation.id = UUID()
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.subject = subject
        conversation.lastReplyPreview = lastReplyPreview
        for participant in participants {
            conversation.addToParticipants(participant)
        }
        return conversation
    }

    // MARK: - Free text

    @MainActor
    func testEmptySearchTextReturnsAllItems() {
        let items: [HubItem] = [
            .post(makePost(subject: "Alpha")),
            .conversation(makeConversation(subject: "Beta"))
        ]
        let result = HubSearchFilter.filter(items: items, searchText: "", token: nil)
        XCTAssertEqual(result.map(\.id), items.map(\.id))
    }

    @MainActor
    func testFreeTextMatchesPostSubjectAndPreview() {
        let matchBySubject = HubItem.post(makePost(subject: "Scuba gear sale"))
        let matchByPreview = HubItem.post(makePost(subject: "Weekly", previewText: "New scuba fins in stock"))
        let miss = HubItem.post(makePost(subject: "Basketball"))
        let result = HubSearchFilter.filter(
            items: [matchBySubject, matchByPreview, miss],
            searchText: "scuba",
            token: nil
        )
        XCTAssertEqual(result.map(\.id), [matchBySubject.id, matchByPreview.id])
    }

    @MainActor
    func testFreeTextMatchesSubscriptionName() {
        let newsDaily = makeSubscription(id: "sub-news", name: "News Daily")
        let promotions = makeSubscription(id: "sub-promo", name: "Promotions")
        let match = HubItem.post(makePost(subject: "Morning briefing", subscription: newsDaily))
        let miss = HubItem.post(makePost(subject: "Half price fins", subscription: promotions))
        let result = HubSearchFilter.filter(items: [match, miss], searchText: "news", token: nil)
        XCTAssertEqual(result.map(\.id), [match.id])
    }

    @MainActor
    func testFreeTextMatchesConversationFieldsAndParticipantName() {
        let alice = makeParticipant(id: "p-alice", name: "Alice Johnson")
        let bySubject = HubItem.conversation(makeConversation(subject: "Ticket refund"))
        let byPreview = HubItem.conversation(
            makeConversation(subject: "Order", lastReplyPreview: "your refund is on its way")
        )
        let byParticipant = HubItem.conversation(
            makeConversation(subject: "Enquiry", participants: [alice])
        )
        let miss = HubItem.conversation(makeConversation(subject: "Other"))
        let items = [bySubject, byPreview, byParticipant, miss]

        let refundResult = HubSearchFilter.filter(items: items, searchText: "refund", token: nil)
        XCTAssertEqual(refundResult.map(\.id), [bySubject.id, byPreview.id])

        let aliceResult = HubSearchFilter.filter(items: items, searchText: "alice", token: nil)
        XCTAssertEqual(aliceResult.map(\.id), [byParticipant.id])
    }

    @MainActor
    func testFreeTextMatchingIsCaseInsensitive() {
        let subscription = makeSubscription(id: "sub-news", name: "News Daily")
        let item = HubItem.post(makePost(subject: "Briefing", subscription: subscription))
        let result = HubSearchFilter.filter(items: [item], searchText: "NEWS", token: nil)
        XCTAssertEqual(result.map(\.id), [item.id])
    }

    // MARK: - Tokens

    @MainActor
    func testSubscriptionTokenNarrowsToThatSubscriptionsPostsByID() {
        let newsDaily = makeSubscription(id: "sub-a", name: "News")
        let duplicateName = makeSubscription(id: "sub-b", name: "News")
        let match = HubItem.post(makePost(subject: "Briefing", subscription: newsDaily))
        let otherSubscription = HubItem.post(makePost(subject: "Briefing", subscription: duplicateName))
        let noSubscription = HubItem.post(makePost(subject: "Briefing"))
        let conversation = HubItem.conversation(makeConversation(subject: "News chat"))
        let token = HubSearchToken.subscription(id: "sub-a", name: "News", logoURL: nil)

        let result = HubSearchFilter.filter(
            items: [match, otherSubscription, noSubscription, conversation],
            searchText: "",
            token: token
        )
        XCTAssertEqual(result.map(\.id), [match.id])
    }

    @MainActor
    func testSubscriptionTokenWithTextSearchesWithinNarrowedPostsOnly() {
        let newsDaily = makeSubscription(id: "sub-a", name: "News Daily")
        let scubaPost = HubItem.post(
            makePost(subject: "Scuba trim counterweights", subscription: newsDaily)
        )
        let otherPost = HubItem.post(makePost(subject: "Basketball recap", subscription: newsDaily))
        let token = HubSearchToken.subscription(id: "sub-a", name: "News Daily", logoURL: nil)

        let result = HubSearchFilter.filter(
            items: [scubaPost, otherPost],
            searchText: "scuba",
            token: token
        )
        XCTAssertEqual(result.map(\.id), [scubaPost.id])
        // The subscription name itself must NOT match within a token —
        // only subject/preview do.
        let nameResult = HubSearchFilter.filter(
            items: [scubaPost, otherPost],
            searchText: "daily",
            token: token
        )
        XCTAssertTrue(nameResult.isEmpty)
    }

    @MainActor
    func testSenderTokenNarrowsToConversationsWithThatParticipant() {
        let alice = makeParticipant(id: "p-alice", name: "Alice Johnson")
        let bob = makeParticipant(id: "p-bob", name: "Bob Newsome")
        let aliceConversation = HubItem.conversation(
            makeConversation(subject: "Refund", participants: [alice])
        )
        let bothConversation = HubItem.conversation(
            makeConversation(subject: "Group chat", participants: [alice, bob])
        )
        let bobConversation = HubItem.conversation(
            makeConversation(subject: "Alice in Wonderland book club", participants: [bob])
        )
        let post = HubItem.post(makePost(subject: "Alice Johnson featured"))
        let token = HubSearchToken.sender(participantID: "p-alice", name: "Alice Johnson", avatarURL: nil)

        let result = HubSearchFilter.filter(
            items: [aliceConversation, bothConversation, bobConversation, post],
            searchText: "",
            token: token
        )
        XCTAssertEqual(result.map(\.id), [aliceConversation.id, bothConversation.id])
    }

    @MainActor
    func testSenderTokenWithTextSearchesWithinNarrowedConversationsOnly() {
        let alice = makeParticipant(id: "p-alice", name: "Alice Johnson")
        let refund = HubItem.conversation(
            makeConversation(subject: "Refund request", participants: [alice])
        )
        let order = HubItem.conversation(
            makeConversation(subject: "Order", lastReplyPreview: "shipped", participants: [alice])
        )
        let token = HubSearchToken.sender(participantID: "p-alice", name: "Alice Johnson", avatarURL: nil)

        let result = HubSearchFilter.filter(
            items: [refund, order],
            searchText: "refund",
            token: token
        )
        XCTAssertEqual(result.map(\.id), [refund.id])
        // The participant name must NOT match within a token.
        let nameResult = HubSearchFilter.filter(
            items: [refund, order],
            searchText: "johnson",
            token: token
        )
        XCTAssertTrue(nameResult.isEmpty)
    }

    // MARK: - Suggestions

    @MainActor
    func testSuggestionsAreEmptyForEmptySearchText() {
        let subscription = makeSubscription(id: "sub-a", name: "News")
        let item = HubItem.post(makePost(subject: "Briefing", subscription: subscription))
        XCTAssertTrue(HubSearchFilter.suggestions(items: [item], searchText: "").isEmpty)
    }

    @MainActor
    func testSuggestionsMatchDedupeAndSkipInvalidCandidates() {
        let newsDaily = makeSubscription(id: "sub-daily", name: "News Daily")
        let placeholder = makeSubscription(id: "sub-placeholder", name: nil)
        let emptyName = makeSubscription(id: "sub-empty", name: "")
        let emptyID = makeSubscription(id: "", name: "News Void")
        let items: [HubItem] = [
            .post(makePost(subject: "One", subscription: newsDaily)),
            .post(makePost(subject: "Two", subscription: newsDaily)),  // dedup by id
            .post(makePost(subject: "Three", subscription: placeholder)),  // nil name skipped
            .post(makePost(subject: "Four", subscription: emptyName)),  // empty name skipped
            .post(makePost(subject: "Five", subscription: emptyID)),  // empty id skipped
            .post(makePost(subject: "Six"))  // no subscription
        ]
        let result = HubSearchFilter.suggestions(items: items, searchText: "news")
        XCTAssertEqual(result, [.subscription(id: "sub-daily", name: "News Daily", logoURL: nil)])
    }

    @MainActor
    func testSuggestionsIncludeParticipantsAndAreCaseInsensitive() {
        let bob = makeParticipant(id: "p-bob", name: "Bob Newsome")
        let anonymous = makeParticipant(id: "p-anon", name: nil)
        let items: [HubItem] = [
            .conversation(makeConversation(subject: "Chat", participants: [bob, anonymous]))
        ]
        let result = HubSearchFilter.suggestions(items: items, searchText: "NEWS")
        XCTAssertEqual(result, [.sender(participantID: "p-bob", name: "Bob Newsome", avatarURL: nil)])
    }

    @MainActor
    func testSuggestionsCarryImageURLs() {
        let logo = URL(string: "https://example.com/logo.png")
        let newsDaily = makeSubscription(id: "sub-a", name: "News Daily", logoURL: logo)
        let bob = makeParticipant(
            id: "p-bob",
            name: "Bob Newsome",
            avatarURL: "https://example.com/bob.png"
        )
        let items: [HubItem] = [
            .post(makePost(subject: "One", subscription: newsDaily)),
            .conversation(makeConversation(subject: "Chat", participants: [bob]))
        ]
        let result = HubSearchFilter.suggestions(items: items, searchText: "news")
        XCTAssertEqual(
            result,
            [
                .subscription(id: "sub-a", name: "News Daily", logoURL: logo),
                .sender(
                    participantID: "p-bob",
                    name: "Bob Newsome",
                    avatarURL: URL(string: "https://example.com/bob.png")
                )
            ]
        )
    }

    @MainActor
    func testSuggestionsOrderSubscriptionsFirstThenLocaleAwareWithIDTieBreak() {
        let zebra = makeSubscription(id: "sub-z", name: "Zebra News")
        let apple = makeSubscription(id: "sub-a", name: "apple news")  // lowercase on purpose
        let tieB = makeSubscription(id: "sub-tie-b", name: "News")
        let tieA = makeSubscription(id: "sub-tie-a", name: "News")
        let bob = makeParticipant(id: "p-bob", name: "Bob Newsome")
        let items: [HubItem] = [
            .post(makePost(subject: "1", subscription: zebra)),
            .post(makePost(subject: "2", subscription: apple)),
            .post(makePost(subject: "3", subscription: tieB)),
            .post(makePost(subject: "4", subscription: tieA)),
            .conversation(makeConversation(subject: "Chat", participants: [bob]))
        ]
        let result = HubSearchFilter.suggestions(items: items, searchText: "news")
        XCTAssertEqual(
            result,
            [
                .subscription(id: "sub-a", name: "apple news", logoURL: nil),
                .subscription(id: "sub-tie-a", name: "News", logoURL: nil),
                .subscription(id: "sub-tie-b", name: "News", logoURL: nil),
                .subscription(id: "sub-z", name: "Zebra News", logoURL: nil),
                .sender(participantID: "p-bob", name: "Bob Newsome", avatarURL: nil)
            ]
        )
    }
}

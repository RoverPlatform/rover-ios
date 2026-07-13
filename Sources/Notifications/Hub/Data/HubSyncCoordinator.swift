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
import RoverData
import UserNotifications
import os.log

/// Returned by every `HubSyncCoordinator` call. Bundles the `conversationStoreGeneration`
/// captured immediately before the network call with the HTTP result, so callers always have
/// access to `generationNumber` — even on failure — enabling generation-guarded saves on
/// both success and failure paths without each actor touching `persistentContainer` directly.
struct HubSyncResponse<T> {
    let generationNumber: Int
    let result: Result<T, Error>
}

/// Wraps `HTTPClient` for all Hub (conversation-, posts-, and subscriptions-domain) Engage API
/// calls and triggers a detached, coalesced hub-wide reset when any call returns HTTP 410 Gone.
///
/// The server returns 410 when it perceives the user's identity to have changed. The cursors we
/// persist encode server-side identity, and — because mobile apps have no true logout flow for
/// seam reasons — the server, not the client, holds the locus of control for logout: when
/// identity or authorization changes, it commands the SDK via 410 to drop all existing state. A
/// 410 from any Hub endpoint — conversations, posts, or subscriptions — therefore triggers a
/// single, unified full-hub reset: all domains are dropped together, since the identity backing
/// all of them just changed at once.
///
/// Every call returns `HubSyncResponse<T>` which carries `generationNumber` on both success and
/// failure paths.
///
/// ## Isolation
///
/// `@MainActor` rather than a plain `actor`, so `register(_:)` can be called **synchronously**
/// from `NotificationsAssembler.containerDidAssemble` at SDK startup, guaranteeing every sync
/// actor is registered before any sync can start — a plain `actor` would force `register` to be
/// `async`, and bridging that with `Task { await ... }` could let a sync race ahead of it. This
/// still gives compiler-enforced isolation for `cancellables` / `invalidationTask` (no lock, no
/// boolean latch), with `register` bridged from the assembler's nonisolated startup path via
/// `MainActor.assumeIsolatedOrFatalError` (same pattern as `ConfigManager`, `HomeViewManager`).
/// Tradeoff: `call()`'s bookkeeping hops onto the main actor per call, though the network I/O
/// itself is unaffected since `await httpCall()` is a suspension point.
///
/// `@unchecked Sendable` is used (rather than a checked `Sendable` conformance) because
/// `DeliveredNotificationCenter`'s closures are not not yet marked `@Sendable`.
@MainActor
final class HubSyncCoordinator: @unchecked Sendable {
    private let httpClient: HTTPClient
    private let persistentContainer: InboxPersistentContainer
    private let notificationCenter: DeliveredNotificationCenter
    private var cancellables: [HubSyncCancellable] = []

    /// Non-nil while a hub-wide reset is in flight. Coalescing is expressed purely via this
    /// handle rather than a boolean latch: a 410 that arrives while this is non-nil is covered
    /// by the in-flight reset and is skipped; a 410 that arrives after it goes back to `nil`
    /// starts a brand new reset, so a store repopulated between resets is never permanently
    /// stuck un-reset.
    private var invalidationTask: Task<Void, Never>?

    init(
        httpClient: HTTPClient,
        persistentContainer: InboxPersistentContainer,
        notificationCenter: DeliveredNotificationCenter = .live
    ) {
        self.httpClient = httpClient
        self.persistentContainer = persistentContainer
        self.notificationCenter = notificationCenter
    }

    /// Registers a cancellable sync actor. Call synchronously during assembly — before
    /// any sync can start — to guarantee a reset will always see all registered actors.
    func register(_ cancellable: HubSyncCancellable) {
        cancellables.append(cancellable)
    }

    // MARK: - Hub HTTP API (conversation domain)

    func getConversationsPage(
        cursor: PageCursor = .forward(nil),
        ifModifiedSince: Date? = nil
    ) async -> HubSyncResponse<ConversationsPageFetchResult> {
        await call { await self.httpClient.getConversationsPage(cursor: cursor, ifModifiedSince: ifModifiedSince) }
    }

    func getRepliesPage(
        conversationID: UUID,
        cursor: PageCursor = .forward(nil)
    ) async -> HubSyncResponse<RepliesSyncResponse> {
        await call { await self.httpClient.getRepliesPage(conversationID: conversationID, cursor: cursor) }
    }

    func sendReply(
        conversationID: UUID,
        content: [ContentBlock],
        externalID: String
    ) async -> HubSyncResponse<Void> {
        await call {
            await self.httpClient.sendReply(
                conversationID: conversationID,
                content: content,
                externalID: externalID
            )
        }
    }

    func markConversationRead(
        conversationID: UUID,
        lastReadReplyID: UUID? = nil
    ) async -> HubSyncResponse<MarkConversationReadResponse> {
        await call {
            await self.httpClient.markConversationRead(
                conversationID: conversationID,
                lastReadReplyID: lastReadReplyID
            )
        }
    }

    func getParticipants() async -> HubSyncResponse<ParticipantsSyncResponse> {
        await call { await self.httpClient.getParticipants() }
    }

    // MARK: - Hub HTTP API (posts domain)

    func getPosts(from cursor: String?) async -> HubSyncResponse<PostsSyncResponse> {
        await call { await self.httpClient.getPosts(from: cursor) }
    }

    // MARK: - Hub HTTP API (subscriptions domain)

    func getSubscriptions() async -> HubSyncResponse<SubscriptionsSyncResponse> {
        await call { await self.httpClient.getSubscriptions() }
    }

    // MARK: - Test hook

    #if DEBUG
        /// Awaits the currently in-flight reset, if any. Test-only: production code must always
        /// fail fast during a reset rather than queue behind it — calling this from a registered
        /// `HubSyncCancellable`'s own tracked task while a reset is in flight would reintroduce a
        /// self-join deadlock, since the reset's `cancelAllTasks()` would be waiting on that very
        /// task. Compiled out of release builds so it cannot be reached from production code
        /// paths; exists purely so tests can deterministically observe post-reset state instead
        /// of racing the detached reset task.
        func awaitCurrentReset() async {
            await invalidationTask?.value
        }
    #endif

    // MARK: - Private

    /// Captures the current store generation, performs the HTTP call, then wraps the result
    /// in `HubSyncResponse` (or triggers a reset on 410).
    ///
    /// Fails fast while a reset is in flight rather than merely relying on the post-hoc
    /// generation check: the epoch is bumped at the *start* of `runReset()`, before
    /// the drops run, so a call that starts after the bump but reads its cursor before the drop
    /// would otherwise capture the already-bumped generation, succeed, and pass
    /// `saveIfGenerationUnchanged` — repopulating from a pre-reset cursor instead of forcing a
    /// clean post-reset resync. Rejecting any call for the full lifetime of `invalidationTask`
    /// (not just new 410s) closes that window.
    private func call<T>(_ httpCall: () async -> Result<T, Error>) async -> HubSyncResponse<T> {
        let generation = persistentContainer.conversationStoreGeneration
        guard invalidationTask == nil else {
            os_log(.debug, log: .hub, "Hub reset in progress — rejecting call until it completes")
            return HubSyncResponse(generationNumber: generation, result: .failure(StaleGenerationError()))
        }
        switch await httpCall() {
        case .failure(let error) where RoverData.isHTTP410(error):
            startResetIfNeeded()
            return HubSyncResponse(generationNumber: generation, result: .failure(StaleGenerationError()))
        case .failure(let error):
            return HubSyncResponse(generationNumber: generation, result: .failure(error))
        case .success(let value):
            return HubSyncResponse(generationNumber: generation, result: .success(value))
        }
    }

    /// Starts a detached, coalesced hub-wide reset if one is not already running. Returns
    /// immediately without awaiting it, to avoid a self-join deadlock: if the reset ran inline on
    /// the failing call's stack, and that stack belonged to a registered actor's own tracked task
    /// (e.g. `ConversationSync.activeSyncTask`), `cancelAllTasks()` would await the very task it
    /// was running on, deadlocking permanently. Spawning the reset as an independent unstructured
    /// `Task` avoids this: `call()`'s caller unwinds immediately (its callers already treat
    /// `StaleGenerationError` as ordinary control flow), so by the time the reset task's
    /// `cancelAllTasks()` runs, the caller's task has already completed and can be awaited safely.
    private func startResetIfNeeded() {
        guard invalidationTask == nil else {
            os_log(.debug, log: .hub, "HTTP 410 received — reset already in progress, skipping")
            return
        }
        os_log(.info, log: .hub, "Received HTTP 410 — invalidating all Hub sync state")
        invalidationTask = Task { @MainActor [weak self] in
            await self?.runReset()
            self?.invalidationTask = nil
        }
    }

    /// Runs one full hub-wide reset.
    ///
    /// Order matters ("epoch-first invalidation"): the epoch is bumped *first*, before
    /// cancellation or drops, so correctness comes from the epoch check rather
    /// than from perfect cancellation timing — a save that slips in before the bump is simply
    /// wiped by the drop that follows it; one that lands after the bump throws
    /// `StaleGenerationError` regardless of whether its task was ever actually cancelled.
    private func runReset() async {
        persistentContainer.bumpConversationStoreGeneration()

        let toCancel = cancellables
        await withTaskGroup(of: Void.self) { group in
            for cancellable in toCancel {
                group.addTask { await cancellable.cancelAllTasks() }
            }
        }

        async let clearNotifications: Void = clearDeliveredHubNotifications()
        persistentContainer.dropAllConversations()
        persistentContainer.dropAllPosts()
        persistentContainer.dropAllSubscriptions()
        await clearNotifications
    }

    /// Removes every delivered notification carrying a Hub push payload (post or conversation).
    ///
    /// Selection is by payload, not by store contents: on iOS a Hub push is only written into Core
    /// Data when the user *taps* it (`InboxPersistentContainer.receiveFromPush`), so a
    /// delivered-but-untapped notification has no row to match against. Any notification already
    /// delivered at reset time predates the identity change that triggered the 410, so it is stale
    /// regardless of whether it was ever synced — and if left in the tray it would re-insert
    /// previous-identity content on tap. Clearing all delivered Hub notifications closes that.
    private func clearDeliveredHubNotifications() async {
        let delivered = await notificationCenter.getDeliveredNotifications()
        let deliveredTuples = delivered.map {
            (
                identifier: $0.request.identifier,
                userInfo: $0.request.content.userInfo
            )
        }
        let toRemove = hubNotificationIdentifiers(from: deliveredTuples)
        if !toRemove.isEmpty {
            notificationCenter.removeDeliveredNotifications(toRemove)
        }
    }

    /// Pure function — extracted for testability. Returns the request identifiers of the delivered
    /// notifications whose payload is a Hub push (`InboxPersistentContainer.hubPushKind` non-nil).
    /// `nonisolated` since it touches no actor-isolated state and is called synchronously from
    /// non-async tests.
    nonisolated func hubNotificationIdentifiers(
        from delivered: [(identifier: String, userInfo: [AnyHashable: Any])]
    ) -> [String] {
        delivered.compactMap { entry in
            InboxPersistentContainer.hubPushKind(from: entry.userInfo) != nil ? entry.identifier : nil
        }
    }

}

// MARK: - Hub HTTP API (HTTPClient extensions)

private extension DateFormatter {
    static let httpIfModifiedSince: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private extension HTTPClient {
    func getConversationsPage(
        cursor: PageCursor = .forward(nil),
        ifModifiedSince: Date? = nil
    ) async -> Result<ConversationsPageFetchResult, Error> {
        let endpoint = engageEndpoint.appendingPathComponent("conversations")
        var queryItems = cursor.queryItems
        queryItems.append(URLQueryItem(name: "include", value: ConversationsSyncResponse.IncludedData.includeKey))

        let ifModifiedSinceHeaders: [String: String] =
            ifModifiedSince.map {
                ["If-Modified-Since": DateFormatter.httpIfModifiedSince.string(from: $0)]
            } ?? [:]

        let request: URLRequest
        do {
            request = try await authenticatedDownloadRequest(
                url: endpoint,
                queryItems: queryItems,
                additionalHeaders: ifModifiedSinceHeaders
            )
        } catch {
            return .failure(error)
        }

        let result = await download(with: request)
        if case .success(_, let response) = result, response.statusCode == 304 {
            return .success(.notModified)
        }
        return downloadDecoding(ConversationsSyncResponse.self, result: result, log: .hub, label: "conversations page")
            .map { .page($0) }
    }

    func getRepliesPage(
        conversationID: UUID,
        cursor: PageCursor = .forward(nil)
    ) async -> Result<RepliesSyncResponse, Error> {
        let endpoint =
            engageEndpoint
            .appendingPathComponent("conversations")
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("replies")
        return await authenticatedDownloadDecoding(
            RepliesSyncResponse.self,
            url: endpoint,
            queryItems: cursor.queryItems,
            log: .hub,
            label: "replies page"
        )
    }

    func sendReply(
        conversationID: UUID,
        content: [ContentBlock],
        externalID: String
    ) async -> Result<Void, Error> {
        let endpoint =
            engageEndpoint
            .appendingPathComponent("conversations")
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("replies")

        let body: Data
        do {
            body = try JSONEncoder.default.encode(SendReplyRequest(content: content, externalID: externalID))
        } catch {
            return .failure(error)
        }

        var request: URLRequest
        do {
            request = try await authenticatedUploadRequest(url: endpoint)
        } catch {
            return .failure(error)
        }
        request.httpBody = body

        do {
            let (data, urlResponse) = try await session.data(for: request)
            switch HTTPResult(data: data, urlResponse: urlResponse, error: nil) {
            case .success(_, let response):
                guard response.statusCode == 202 else {
                    return .failure(
                        SendReplyError.retryable(
                            makeHTTPStatusCodeError(statusCode: response.statusCode, responseBody: data)
                        )
                    )
                }
                return .success(())
            case .error(let error, let isRetryable):
                let err = error ?? URLError(.unknown)
                if RoverData.isHTTP410(err) { return .failure(err) }
                return .failure(isRetryable ? SendReplyError.retryable(err) : SendReplyError.terminal(err))
            }
        } catch {
            return .failure(SendReplyError.retryable(error))
        }
    }

    func markConversationRead(
        conversationID: UUID,
        lastReadReplyID: UUID? = nil
    ) async -> Result<MarkConversationReadResponse, Error> {
        let endpoint =
            engageEndpoint
            .appendingPathComponent("conversations")
            .appendingPathComponent(conversationID.uuidString)
            .appendingPathComponent("read")

        let body: Data
        do {
            body = try JSONEncoder.default.encode(MarkConversationReadRequest(lastReadReplyID: lastReadReplyID))
        } catch {
            return .failure(error)
        }

        var request: URLRequest
        do {
            request = try await authenticatedUploadRequest(url: endpoint)
        } catch {
            return .failure(error)
        }
        request.httpBody = body

        return await downloadDecoding(
            MarkConversationReadResponse.self,
            with: request,
            log: .hub,
            label: "mark-read"
        )
    }

    func getParticipants() async -> Result<ParticipantsSyncResponse, Error> {
        let endpoint = engageEndpoint.appendingPathComponent("participants")
        return await authenticatedDownloadDecoding(
            ParticipantsSyncResponse.self,
            url: endpoint,
            log: .hub,
            label: "participants"
        )
    }
}

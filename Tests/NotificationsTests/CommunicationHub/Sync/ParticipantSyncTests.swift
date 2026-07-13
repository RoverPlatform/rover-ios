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

@testable import RoverData
@testable import RoverNotifications

final class ParticipantSyncTests: HubSyncTestBase {

    var participantSync: ParticipantSync!

    override func setUp() async throws {
        try await super.setUp()
        participantSync = ParticipantSync(
            persistentContainer: testContainer,
            hubSyncCoordinator: hubSyncCoordinator
        )
    }

    override func tearDown() async throws {
        participantSync = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testSuccessfulSyncUpsertParticipantsAndReturnsTrue() async {
        let participants = TestDataGenerator.createTestParticipants(count: 2)
        URLProtocolMock.stubParticipants(participants)

        let result = await participantSync.sync()

        XCTAssertTrue(result, "sync() should return true on success")
        let saved = await fetchAllParticipants()
        XCTAssertEqual(saved.count, 2, "All participants should be persisted to Core Data")
        XCTAssertTrue(
            saved.contains(where: { $0.name == "Participant 0" }),
            "Participant data should be saved"
        )
    }

    func testNetworkFailureReturnsFalseAndWritesNothing() async {
        URLProtocolMock.stubParticipantsError(URLError(.networkConnectionLost), statusCode: 0)

        let result = await participantSync.sync()

        XCTAssertFalse(result, "sync() should return false on network failure")
        let saved = await fetchAllParticipants()
        XCTAssertEqual(saved.count, 0, "No participants should be written to Core Data on failure")
    }

    func testConcurrentSyncCallsCoalesce() async {
        URLProtocolMock.setNetworkLatency(0.2)
        let participants = TestDataGenerator.createTestParticipants(count: 2)
        URLProtocolMock.stubParticipants(participants)

        let results = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await self.participantSync.sync() }
            group.addTask { await self.participantSync.sync() }
            group.addTask { await self.participantSync.sync() }
            var all: [Bool] = []
            for await result in group { all.append(result) }
            return all
        }

        XCTAssertTrue(results.allSatisfy { $0 }, "All coalesced sync() calls should return true")
        let calls = URLProtocolMock.getCallLog()
            .filter { $0.url?.path.contains("/participants") == true }
            .count
        XCTAssertEqual(
            calls,
            1,
            "Only one participants request should be made despite 3 concurrent sync() calls"
        )
    }

    func testSyncWaitsForContainerToLoad() async {
        // Reset published flag to force performActualSync() into the wait loop.
        // The Core Data stack is already initialised - only the flag is being manipulated.
        await MainActor.run { testContainer.state = .loading }

        let participants = TestDataGenerator.createTestParticipants(count: 1)
        URLProtocolMock.stubParticipants(participants)

        let syncTask = Task { await participantSync.sync() }

        await Task.yield()
        await MainActor.run { testContainer.state = .loaded }

        let networkCallSeen = await waitUntil {
            URLProtocolMock.getCallLog()
                .filter { $0.url?.path.contains("/participants") == true }
                .isEmpty == false
        }
        XCTAssertTrue(networkCallSeen, "sync() should make a network call once the container transitions to .loaded")

        let result = await syncTask.value
        XCTAssertTrue(result, "sync() must succeed once the container transitions to .loaded")
        let saved = await fetchAllParticipants()
        XCTAssertEqual(saved.count, 1, "Participants should be persisted after the container finishes loading")
    }

    func testRequestIncludesDeviceIdentifier() async {
        var capturedDeviceIdentifier: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/participants") else { return nil }
            capturedDeviceIdentifier = url.queryParameters?["deviceIdentifier"]
            return .success(object: ParticipantsSyncResponse(participants: []))
        }

        _ = await participantSync.sync()

        XCTAssertNotNil(capturedDeviceIdentifier, "participants request must include deviceIdentifier query param")
    }

    func testRequestIncludesUserIDWhenSet() async {
        mockUserInfoManager.mockUserID = "user-abc"

        var capturedUserID: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/participants") else { return nil }
            capturedUserID = url.queryParameters?["userID"]
            return .success(object: ParticipantsSyncResponse(participants: []))
        }

        _ = await participantSync.sync()

        XCTAssertEqual(
            capturedUserID,
            "user-abc",
            "participants request must include userID when set in UserInfoManager"
        )
    }

    func testRequestOmitsUserIDWhenAbsent() async {
        var requestSeen = false
        var queryContainedUserID = false
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/participants") else { return nil }
            requestSeen = true
            queryContainedUserID = url.queryParameters?["userID"] != nil
            return .success(object: ParticipantsSyncResponse(participants: []))
        }

        _ = await participantSync.sync()

        XCTAssertTrue(requestSeen, "testRequestOmitsUserIDWhenAbsent must observe a participants request")
        XCTAssertFalse(
            queryContainedUserID,
            "participants request must not include userID when absent from UserInfoManager"
        )
    }

    // MARK: - Helpers

    private func fetchAllParticipants() async -> [Participant] {
        await MainActor.run {
            let request: NSFetchRequest<Participant> = Participant.fetchRequest()
            return (try? testContainer.viewContext.fetch(request)) ?? []
        }
    }
}

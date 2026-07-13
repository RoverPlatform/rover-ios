// Tests/DataTests/SyncCoordinatorServiceTests.swift
import UIKit
import XCTest

@testable import RoverData

private final class MockStandaloneParticipant: SyncStandaloneParticipant {
    let returnValue: Bool

    init(returns returnValue: Bool) {
        self.returnValue = returnValue
    }

    func sync() async -> Bool {
        returnValue
    }
}

private actor StartGate {
    private let expectedCount: Int
    private var startedCount = 0
    private var startedWaiters: [CheckedContinuation<Bool, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>]? = []

    init(expectedCount: Int) {
        self.expectedCount = expectedCount
    }

    func markStarted() {
        startedCount += 1
        if startedCount == expectedCount {
            startedWaiters.forEach { $0.resume(returning: true) }
            startedWaiters.removeAll()
        }
    }

    /// Returns true when all expected participants have called markStarted(),
    /// or false if cancelWaiters() is called first (e.g. after a test timeout).
    func waitUntilAllStarted() async -> Bool {
        guard startedCount < expectedCount else { return true }
        return await withCheckedContinuation { continuation in
            startedWaiters.append(continuation)
        }
    }

    /// Resumes any pending waitUntilAllStarted() continuations with false.
    /// Call after a timeout to guarantee no continuation is left suspended.
    func cancelWaiters() {
        startedWaiters.forEach { $0.resume(returning: false) }
        startedWaiters.removeAll()
    }

    func waitForRelease() async {
        guard releaseWaiters != nil else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters?.append(continuation)
        }
    }

    func releaseAll() {
        releaseWaiters?.forEach { $0.resume() }
        releaseWaiters = nil
    }
}

private final class BlockingStandaloneParticipant: SyncStandaloneParticipant {
    let gate: StartGate

    init(gate: StartGate) {
        self.gate = gate
    }

    func sync() async -> Bool {
        await gate.markStarted()
        await gate.waitForRelease()
        return false
    }
}

final class SyncCoordinatorServiceTests: XCTestCase {

    private func runSync(_ service: SyncCoordinatorService) async -> UIBackgroundFetchResult {
        await withCheckedContinuation { continuation in
            service.sync { result in
                continuation.resume(returning: result)
            }
        }
    }

    func test_syncStandaloneParticipants_noParticipants_yieldsNoData() async {
        let service = SyncCoordinatorService(client: MockSyncClient())

        let result = await runSync(service)

        XCTAssertEqual(result, .noData)
    }

    func test_syncStandaloneParticipants_allReturnFalse_yieldsNoData() async {
        let service = SyncCoordinatorService(client: MockSyncClient())
        service.registerStandaloneParticipant(MockStandaloneParticipant(returns: false))
        service.registerStandaloneParticipant(MockStandaloneParticipant(returns: false))

        let result = await runSync(service)

        XCTAssertEqual(result, .noData)
    }

    func test_syncStandaloneParticipants_oneReturnsTrue_yieldsNewData() async {
        let service = SyncCoordinatorService(client: MockSyncClient())
        service.registerStandaloneParticipant(MockStandaloneParticipant(returns: false))
        service.registerStandaloneParticipant(MockStandaloneParticipant(returns: true))

        let result = await runSync(service)

        XCTAssertEqual(result, .newData)
    }

    private func waitUntilAllParticipantsStart(
        gate: StartGate,
        timeout: TimeInterval = 2.0
    ) async {
        let started = expectation(description: "all participants started")
        Task {
            if await gate.waitUntilAllStarted() {
                started.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: timeout)
        await gate.cancelWaiters()
    }

    func test_syncStandaloneParticipants_startsAllParticipantsBeforeAnyFinishes() async {
        let service = SyncCoordinatorService(client: MockSyncClient())
        let gate = StartGate(expectedCount: 3)

        service.registerStandaloneParticipant(BlockingStandaloneParticipant(gate: gate))
        service.registerStandaloneParticipant(BlockingStandaloneParticipant(gate: gate))
        service.registerStandaloneParticipant(BlockingStandaloneParticipant(gate: gate))

        let syncTask = Task { await runSync(service) }

        await waitUntilAllParticipantsStart(gate: gate)

        await gate.releaseAll()
        let result = await syncTask.value
        XCTAssertEqual(result, .noData)
    }
}

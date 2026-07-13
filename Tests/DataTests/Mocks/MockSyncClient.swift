// Tests/DataTests/Mocks/MockSyncClient.swift
import Foundation

@testable import RoverData

class MockSyncClient: SyncClient {
    func sync(with syncRequests: [SyncRequest]) async throws -> Data {
        return Data()
    }
}

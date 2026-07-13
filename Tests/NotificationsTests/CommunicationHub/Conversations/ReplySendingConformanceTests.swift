import XCTest

@testable import RoverNotifications

/// Compile-time check: ReplySending protocol exists with the correct method signature.
/// The test passes if it compiles; no runtime assertion is needed.
final class ReplySendingConformanceTests: XCTestCase {
    func testReplySendingProtocolExists() {
        struct MinimalConformer: ReplySending {
            func sendReply(conversationID: UUID, text: String) async -> Task<Bool, Never>? { nil }
            func markConversationRead(conversationID: UUID) async -> Result<MarkConversationReadResponse, Error> {
                .failure(NSError(domain: "mock", code: 0))
            }
            func markConversationReadLocally(conversationID: UUID, lastReadReplyID: UUID) async {}
        }
        func acceptsSending(_: any ReplySending) {}
        acceptsSending(MinimalConformer())
    }
}

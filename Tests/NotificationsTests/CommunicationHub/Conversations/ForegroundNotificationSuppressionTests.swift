import XCTest

@testable import RoverNotifications

final class ForegroundNotificationSuppressionTests: XCTestCase {

    private lazy var handler = NotificationHandlerService(
        dispatcher: MockDispatcher(),
        influenceTracker: MockInfluenceTracker(),
        notificationActionProvider: { _ in nil },
        openURLActionProvider: { _ in nil },
        replySync: MockReplySending(),
        inboxPersistentContainer: nil
    )

    static let conversationID = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!
    static let otherConversationID = UUID(uuidString: "11111111-0000-0000-0000-000000000002")!

    func testSuppressesWhenDisplayedConversationMatchesPayload() {
        let userInfo = makeConversationUserInfo(conversationID: Self.conversationID)
        let options = handler.willPresent(userInfo: userInfo, displayedConversationID: Self.conversationID)
        XCTAssertEqual(options, [])
    }

    func testPresentsWhenDisplayedConversationDiffers() {
        let userInfo = makeConversationUserInfo(conversationID: Self.conversationID)
        let options = handler.willPresent(userInfo: userInfo, displayedConversationID: Self.otherConversationID)
        XCTAssertEqual(options, [.sound, .banner])
    }

    func testPresentsWhenPayloadHasNoConversationID() {
        let userInfo: [AnyHashable: Any] = ["rover": [:] as [String: Any]]
        let options = handler.willPresent(userInfo: userInfo, displayedConversationID: Self.conversationID)
        XCTAssertEqual(options, [.sound, .banner])
    }

    func testPresentsWhenNoConversationDisplayed() {
        let userInfo = makeConversationUserInfo(conversationID: Self.conversationID)
        let options = handler.willPresent(userInfo: userInfo, displayedConversationID: nil)
        XCTAssertEqual(options, [.sound, .banner])
    }

}

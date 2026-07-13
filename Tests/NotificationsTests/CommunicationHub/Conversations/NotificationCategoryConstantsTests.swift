import UserNotifications
import XCTest

@testable import RoverNotifications

final class NotificationCategoryConstantsTests: XCTestCase {

    func testCategoryIdentifierValue() {
        XCTAssertEqual(NotificationCategories.conversationReply, "io.rover.conversation.reply")
    }

    func testActionIdentifierValue() {
        XCTAssertEqual(NotificationCategories.inlineReplyAction, "io.rover.conversation.inline-reply")
    }

    func testRoverCategoryHasExpectedAction() throws {
        let categories = NotificationsAssembler.roverNotificationCategories
        let category = try XCTUnwrap(
            categories.first { $0.identifier == NotificationCategories.conversationReply },
            "roverNotificationCategories must include the conversation-reply category"
        )
        XCTAssertEqual(category.actions.count, 1)
        let action = try XCTUnwrap(category.actions.first, "conversation-reply category must include an action")
        XCTAssertEqual(action.identifier, NotificationCategories.inlineReplyAction)
        XCTAssertEqual(action.title, "Reply")
    }

    func testRoverReplyActionIsTextInput() throws {
        let categories = NotificationsAssembler.roverNotificationCategories
        let category = try XCTUnwrap(
            categories.first { $0.identifier == NotificationCategories.conversationReply },
            "roverNotificationCategories must include the conversation-reply category"
        )
        let action = try XCTUnwrap(
            category.actions.first as? UNTextInputNotificationAction,
            "inline-reply action must be a UNTextInputNotificationAction"
        )
        XCTAssertEqual(action.textInputButtonTitle, "Send")
        XCTAssertEqual(action.textInputPlaceholder, "Reply...")
    }
}

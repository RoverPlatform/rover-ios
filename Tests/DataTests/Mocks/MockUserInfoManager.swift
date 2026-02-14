import RoverFoundation

@testable import RoverData

/// Test double for UserInfoManager with an in-memory userInfo store.
class MockUserInfoManager: UserInfoManager {
    var userInfo: [String: Any] = [:]

    var currentUserInfo: [String: Any] {
        return userInfo
    }

    func updateUserInfo(block: (inout Attributes) -> Void) {
        // Not needed for these tests
    }

    func clearUserInfo() {
        userInfo = [:]
    }
}

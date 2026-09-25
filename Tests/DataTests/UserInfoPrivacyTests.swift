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

import RoverFoundation
import XCTest

@testable import RoverData

final class UserInfoPrivacyTests: XCTestCase {
    private let storedUserInfo: [String: Any] = [
        "userID": "user-123",
        "name": "Sam",
        "ticketmaster": ["ticketmasterID": "tm-456"],
        "seatGeek": ["seatGeekClientID": "sg-789"],
        "axs": ["userID": "axs-000"],
        "ecid": "ecid-111"
    ]

    func testDefaultModeReportsEverything() {
        let reported = UserInfoPrivacy.reportedUserInfo(storedUserInfo, trackingMode: .default)

        XCTAssertEqual(Set(reported.keys), Set(storedUserInfo.keys))
    }

    func testAnonymizedModeWithholdsTheSensitiveKeys() {
        let reported = UserInfoPrivacy.reportedUserInfo(storedUserInfo, trackingMode: .anonymized)

        XCTAssertEqual(Set(reported.keys), ["userID", "name"])
    }

    @available(*, deprecated, message: "Exercises the deprecated .anonymous mode on purpose.")
    func testAnonymousModeWithholdsTheSensitiveKeys() {
        let reported = UserInfoPrivacy.reportedUserInfo(storedUserInfo, trackingMode: .anonymous)

        XCTAssertEqual(Set(reported.keys), ["userID", "name"])
    }

    func testAttributesAreFilteredWithoutMutatingTheStoredValue() {
        let stored = Attributes(rawValue: storedUserInfo)

        let reported = UserInfoPrivacy.reportedUserInfo(stored, trackingMode: .anonymized)

        XCTAssertEqual(Set(reported?.rawValue.keys ?? [:].keys), ["userID", "name"])
        XCTAssertEqual(Set(stored.rawValue.keys), Set(storedUserInfo.keys))
    }

    func testAttributesInDefaultModeAreReportedUnchanged() {
        let stored = Attributes(rawValue: storedUserInfo)

        let reported = UserInfoPrivacy.reportedUserInfo(stored, trackingMode: .default)

        XCTAssertEqual(Set(reported?.rawValue.keys ?? [:].keys), Set(storedUserInfo.keys))
    }

    func testNilAttributesStayNil() {
        XCTAssertNil(UserInfoPrivacy.reportedUserInfo(nil, trackingMode: .anonymized))
        XCTAssertNil(UserInfoPrivacy.reportedUserInfo(nil, trackingMode: .default))
    }

    func testNestedSensitiveValuesAreKeptIntactWhenReported() {
        let stored = Attributes(rawValue: storedUserInfo)

        let reported = UserInfoPrivacy.reportedUserInfo(stored, trackingMode: .default)
        let ticketmaster = reported?.rawValue["ticketmaster"] as? Attributes

        XCTAssertEqual(ticketmaster?.rawValue["ticketmasterID"] as? String, "tm-456")
    }
}

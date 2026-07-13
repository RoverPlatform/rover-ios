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

import XCTest

@testable import RoverData

final class ResolvedIdentifiersTests: XCTestCase {

    private var mockUserInfoManager: MockUserInfoManager!

    override func setUp() async throws {
        try await super.setUp()
        mockUserInfoManager = MockUserInfoManager()
    }

    override func tearDown() async throws {
        mockUserInfoManager = nil
        try await super.tearDown()
    }

    // MARK: - ResolvedIdentifiers.queryItems tests

    func testQueryItemsIncludesBothWhenUserIDPresent() {
        let identifiers = ResolvedIdentifiers(userID: "user-abc", deviceIdentifier: "device-xyz")
        let items = identifiers.queryItems
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first(where: { $0.name == "userID" })?.value, "user-abc")
        XCTAssertEqual(items.first(where: { $0.name == "deviceIdentifier" })?.value, "device-xyz")
    }

    func testQueryItemsIncludesOnlyDeviceIdentifierWhenNoUserID() {
        let identifiers = ResolvedIdentifiers(userID: nil, deviceIdentifier: "device-xyz")
        let items = identifiers.queryItems
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "deviceIdentifier")
        XCTAssertEqual(items.first?.value, "device-xyz")
    }

    func testQueryItemsIncludesDeviceIdentifierEvenWhenEmpty() {
        let identifiers = ResolvedIdentifiers(userID: nil, deviceIdentifier: "")
        let items = identifiers.queryItems
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "deviceIdentifier")
        XCTAssertEqual(items.first?.value, "")
    }

    // MARK: - resolveIdentifiers tests

    func testUserIDWinsOverAllOthers() async {
        mockUserInfoManager.userInfo = [
            "userID": "user-123",
            "ticketmaster": ["ticketmasterID": "tm-456"],
            "seatGeek": ["seatGeekClientID": "sg-client-789", "seatGeekID": "sg-crm-000"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "user-123")
    }

    func testTicketmasterIDWinsWhenNoUserID() async {
        mockUserInfoManager.userInfo = [
            "ticketmaster": ["ticketmasterID": "tm-456"],
            "seatGeek": ["seatGeekClientID": "sg-client-789", "seatGeekID": "sg-crm-000"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "tm-456")
    }

    func testSeatGeekClientIDWinsWhenNoUserIDOrTicketmaster() async {
        mockUserInfoManager.userInfo = [
            "seatGeek": ["seatGeekClientID": "sg-client-789", "seatGeekID": "sg-crm-000"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "sg-client-789")
    }

    func testSeatGeekCRMIDWinsWhenNoHigherPriorityIdentifier() async {
        mockUserInfoManager.userInfo = [
            "seatGeek": ["seatGeekID": "sg-crm-000"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "sg-crm-000")
    }

    func testFallsBackToDeviceIdentifierWhenNoUserIdentifiers() async {
        mockUserInfoManager.userInfo = [:]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertNil(identifiers.userID)
        XCTAssertFalse(identifiers.deviceIdentifier.isEmpty)
    }

    func testEmptyUserIDFallsThroughToTicketmaster() async {
        mockUserInfoManager.userInfo = [
            "userID": "",
            "ticketmaster": ["ticketmasterID": "tm-456"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "tm-456")
    }

    func testEmptyTicketmasterIDFallsThroughToSeatGeekClientID() async {
        mockUserInfoManager.userInfo = [
            "ticketmaster": ["ticketmasterID": ""],
            "seatGeek": ["seatGeekClientID": "sg-client-789"]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertEqual(identifiers.userID, "sg-client-789")
    }

    func testAllEmptyStringsFallBackToDeviceIdentifier() async {
        mockUserInfoManager.userInfo = [
            "userID": "",
            "ticketmaster": ["ticketmasterID": ""],
            "seatGeek": ["seatGeekClientID": "", "seatGeekID": ""]
        ]
        let identifiers = await resolveIdentifiers(userInfoManager: mockUserInfoManager)
        XCTAssertNil(identifiers.userID)
        XCTAssertFalse(identifiers.deviceIdentifier.isEmpty)
    }
}

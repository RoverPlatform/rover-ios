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

final class ContextManagerTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var privacyService: PrivacyService!
    private var contextManager: ContextManager!

    override func setUp() {
        super.setUp()
        suiteName = "io.rover.ContextManagerTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        privacyService = PrivacyService(userDefaults: userDefaults)
        contextManager = ContextManager(privacyService: privacyService, userDefaults: userDefaults)
    }

    override func tearDown() {
        contextManager = nil
        privacyService = nil
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Reported user info

    func testReportedUserInfoIncludesSensitiveKeysInDefaultMode() {
        privacyService.trackingMode = .default
        contextManager.updateUserInfo { $0.rawValue["ticketmaster"] = Attributes(rawValue: ["ticketmasterID": "tm-1"]) }

        let ticketmaster = contextManager.userInfo?.rawValue["ticketmaster"] as? Attributes

        XCTAssertEqual(ticketmaster?.rawValue["ticketmasterID"] as? String, "tm-1")
    }

    func testReportedUserInfoWithholdsSensitiveKeysWhileAnonymized() {
        contextManager.updateUserInfo {
            $0.rawValue["ticketmaster"] = Attributes(rawValue: ["ticketmasterID": "tm-1"])
            $0.rawValue["seatGeek"] = Attributes(rawValue: ["seatGeekClientID": "sg-1"])
            $0.rawValue["axs"] = Attributes(rawValue: ["userID": "axs-1"])
            $0.rawValue["ecid"] = "ecid-1"
            $0.rawValue["favouriteTeam"] = "Leafs"
        }

        privacyService.trackingMode = .anonymized

        XCTAssertEqual(Set(contextManager.userInfo?.rawValue.keys ?? [:].keys), ["favouriteTeam"])
    }

    func testStoredUserInfoSurvivesAnonymizedModeAndComesBack() {
        privacyService.trackingMode = .anonymized
        contextManager.updateUserInfo { $0.rawValue["ticketmaster"] = Attributes(rawValue: ["ticketmasterID": "tm-1"]) }

        // Set while anonymized: stored and visible to the host, but withheld from anything leaving the SDK.
        let storedTicketmaster = contextManager.currentUserInfo["ticketmaster"] as? [String: Any]
        XCTAssertEqual(storedTicketmaster?["ticketmasterID"] as? String, "tm-1")
        XCTAssertNil(contextManager.userInfo?.rawValue["ticketmaster"])

        privacyService.trackingMode = .default

        let reportedTicketmaster = contextManager.userInfo?.rawValue["ticketmaster"] as? Attributes
        XCTAssertEqual(reportedTicketmaster?.rawValue["ticketmasterID"] as? String, "tm-1")
    }

    // MARK: - Privacy listener

    func testOnlyAGenuineTrackingModeTransitionReportsAUserInfoChange() {
        let spy = SpyContextManager(privacyService: privacyService, userDefaults: userDefaults)

        // Registration primes the listener with the current mode, which is not a change.
        privacyService.registerTrackingEnabledListener(spy)
        XCTAssertEqual(spy.reportedUserInfoDidChangeCount, 0)

        privacyService.trackingMode = .anonymized
        XCTAssertEqual(spy.reportedUserInfoDidChangeCount, 1)

        // The setter re-notifies listeners even when the value is unchanged.
        privacyService.trackingMode = .anonymized
        XCTAssertEqual(spy.reportedUserInfoDidChangeCount, 1)

        privacyService.trackingMode = .default
        XCTAssertEqual(spy.reportedUserInfoDidChangeCount, 2)
    }

    // MARK: - Provisioning profile

    func testProvisioningProfileEnvironmentReturnsDevelopment() {
        let data = makeProvisioningProfileData(apsEnvironment: "development")

        let environment = ContextManager.provisioningProfileEnvironment(from: data)

        XCTAssertEqual(environment, .development)
    }

    func testProvisioningProfileEnvironmentReturnsProduction() {
        let data = makeProvisioningProfileData(apsEnvironment: "production")

        let environment = ContextManager.provisioningProfileEnvironment(from: data)

        XCTAssertEqual(environment, .production)
    }

    func testProvisioningProfileEnvironmentReturnsNilForUnknownValue() {
        let data = makeProvisioningProfileData(apsEnvironment: "sandbox")

        let environment = ContextManager.provisioningProfileEnvironment(from: data)

        XCTAssertNil(environment)
    }

    func testProvisioningProfileEnvironmentReturnsNilWhenXMLPayloadMissing() {
        let data = Data("not a provisioning profile".utf8)

        let environment = ContextManager.provisioningProfileEnvironment(from: data)

        XCTAssertNil(environment)
    }

    func testProvisioningProfileEnvironmentReturnsNilWhenClosingMarkerPrecedesHeader() {
        let data =
            Data("</plist>".utf8)
            + Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist><dict>".utf8)

        let environment = ContextManager.provisioningProfileEnvironment(from: data)

        XCTAssertNil(environment)
    }

    private func makeProvisioningProfileData(apsEnvironment: String) -> Data {
        // Real embedded.mobileprovision files wrap the XML plist in binary CMS data.
        // Prefixing and suffixing the plist ensures we test extraction from a larger binary blob.
        return Data([0x30, 0x82, 0x04, 0xA3]) + makeProvisioningProfileXML(apsEnvironment: apsEnvironment)
            + Data([0xDE, 0xAD, 0xBE, 0xEF])
    }

    private func makeProvisioningProfileXML(apsEnvironment: String) -> Data {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Entitlements</key>
                <dict>
                    <key>aps-environment</key>
                    <string>\(apsEnvironment)</string>
                </dict>
            </dict>
            </plist>
            """

        return Data(xml.utf8)
    }
}

private final class SpyContextManager: ContextManager {
    private(set) var reportedUserInfoDidChangeCount = 0

    override func reportedUserInfoDidChange() {
        reportedUserInfoDidChangeCount += 1
    }
}

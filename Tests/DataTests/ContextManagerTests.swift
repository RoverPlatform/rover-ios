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

final class ContextManagerTests: XCTestCase {
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

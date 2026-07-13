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
@testable import RoverUI

/// Minimal DI container/resolver double mirroring `Rover`'s conformance, so the
/// assembler wiring can be exercised without a full SDK assembly.
private final class TestContainer: Container, Resolver {
    private var services = [ServiceKey: Any]()

    func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey) {
        services[key] = entry
    }

    func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>? {
        services[key] as? ServiceEntry<Service>
    }
}

final class UIAssemblerAuthDomainsTests: XCTestCase {

    func testAssociatedDomainsAreEnabledForSDKAuth() {
        let container = TestContainer()
        // Register the AuthenticationContext the way DataAssembler does.
        container.register(AuthenticationContext.self) { _ in
            AuthenticationContext()
        }

        let assembler = UIAssembler(
            associatedDomains: ["example.rover-customer.com"],
            urlSchemes: [],
            isLifeCycleTrackingEnabled: false,
            isVersionTrackingEnabled: false
        )
        assembler.assemble(container: container)
        assembler.containerDidAssemble(resolver: container)

        let authContext = container.resolve(AuthenticationContext.self)!
        XCTAssertTrue(
            authContext.sdkAuthenticationEnabledDomains.contains("example.rover-customer.com"),
            "Every associatedDomains entry should be enabled for SDK auth token attachment"
        )
        // The built-in default must remain enabled alongside the new entry.
        XCTAssertTrue(authContext.sdkAuthenticationEnabledDomains.contains("*.rover.io"))
    }
}

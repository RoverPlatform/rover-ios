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

@testable import RoverData
import XCTest

class MatchDomainPatternTests: XCTestCase {

    // MARK: - Single-label hostname (localhost)

    func testLocalhostExactMatch() {
        XCTAssertTrue(matchDomainPattern(string: "localhost", pattern: "localhost"))
    }

    func testLocalhostDoesNotMatchVercelWildcard() {
        XCTAssertFalse(matchDomainPattern(string: "localhost", pattern: "*.vercel.app"))
    }

    func testLocalhostDoesNotMatchIoWildcard() {
        XCTAssertFalse(matchDomainPattern(string: "localhost", pattern: "*.io"))
    }

    func testLocalhostApexMatchesLocalhostWildcard() {
        // *.localhost apex: string == root
        XCTAssertTrue(matchDomainPattern(string: "localhost", pattern: "*.localhost"))
    }

    func testSubdomainOfLocalhostMatchesLocalhostWildcard() {
        // Primary dev use case: api.localhost against *.localhost
        XCTAssertTrue(matchDomainPattern(string: "api.localhost", pattern: "*.localhost"))
    }

    // MARK: - Multi-label exact match

    func testExactMatchRoverIo() {
        XCTAssertTrue(matchDomainPattern(string: "rover.io", pattern: "rover.io"))
    }

    func testSubdomainDoesNotMatchExactPattern() {
        XCTAssertFalse(matchDomainPattern(string: "api.rover.io", pattern: "rover.io"))
    }

    // MARK: - Wildcard match

    func testSubdomainMatchesWildcard() {
        XCTAssertTrue(matchDomainPattern(string: "api.rover.io", pattern: "*.rover.io"))
    }

    func testApexMatchesWildcard() {
        // The bare root domain also matches *.root
        XCTAssertTrue(matchDomainPattern(string: "rover.io", pattern: "*.rover.io"))
    }

    func testVercelSubdomainMatchesVercelWildcard() {
        XCTAssertTrue(matchDomainPattern(string: "datasource-testing.vercel.app", pattern: "*.vercel.app"))
    }

    func testCrossWildcardDoesNotMatch() {
        XCTAssertFalse(matchDomainPattern(string: "api.rover.io", pattern: "*.vercel.app"))
    }

    // MARK: - Invalid / edge cases

    func testMultipleWildcardsAreRejected() {
        XCTAssertFalse(matchDomainPattern(string: "api.foo.bar", pattern: "*.foo.*.bar"))
    }

    func testEmptyStringReturnsFalse() {
        XCTAssertFalse(matchDomainPattern(string: "", pattern: ""))
    }
}

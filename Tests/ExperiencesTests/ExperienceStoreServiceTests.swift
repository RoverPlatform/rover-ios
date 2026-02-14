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

import CryptoKit
import XCTest

@testable import RoverExperiences

final class ExperienceStoreServiceTests: XCTestCase {

    // MARK: - ExperienceFingerprint Tests

    func testFingerprintEqualityWhenIdentical() {
        let data = "test data".data(using: .utf8)!
        let hash = Data(SHA256.hash(data: data))

        let fp1 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: ["key": "val"])
        let fp2 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: ["key": "val"])

        XCTAssertEqual(fp1, fp2)
    }

    func testFingerprintInequalityWhenDataDiffers() {
        let hash1 = Data(SHA256.hash(data: "data1".data(using: .utf8)!))
        let hash2 = Data(SHA256.hash(data: "data2".data(using: .utf8)!))

        let fp1 = ExperienceFingerprint(
            dataHash: hash1, version: "2", id: "abc", name: "Test", urlParameters: [:])
        let fp2 = ExperienceFingerprint(
            dataHash: hash2, version: "2", id: "abc", name: "Test", urlParameters: [:])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintInequalityWhenParametersDiffer() {
        let hash = Data(SHA256.hash(data: "data".data(using: .utf8)!))

        let fp1 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: ["a": "1"])
        let fp2 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: ["a": "2"])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintInequalityWhenVersionDiffers() {
        let hash = Data(SHA256.hash(data: "data".data(using: .utf8)!))

        let fp1 = ExperienceFingerprint(
            dataHash: hash, version: "1", id: "abc", name: "Test", urlParameters: [:])
        let fp2 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: [:])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintInequalityWhenIdDiffers() {
        let hash = Data(SHA256.hash(data: "data".data(using: .utf8)!))

        let fp1 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test", urlParameters: [:])
        let fp2 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "def", name: "Test", urlParameters: [:])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintInequalityWhenNameDiffers() {
        let hash = Data(SHA256.hash(data: "data".data(using: .utf8)!))

        let fp1 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test1", urlParameters: [:])
        let fp2 = ExperienceFingerprint(
            dataHash: hash, version: "2", id: "abc", name: "Test2", urlParameters: [:])

        XCTAssertNotEqual(fp1, fp2)
    }

    func testFingerprintFromDownloadResult() {
        let data = ExperienceFixtures.simpleScreenJSON
        let result = ExperienceDownloadResult(
            data: data, version: "2", id: "exp-1", name: "My Exp", urlParameters: ["k": "v"])

        let fingerprint = ExperienceFingerprint(from: result)

        XCTAssertEqual(fingerprint.dataHash, Data(SHA256.hash(data: data)))
        XCTAssertEqual(fingerprint.version, "2")
        XCTAssertEqual(fingerprint.id, "exp-1")
        XCTAssertEqual(fingerprint.name, "My Exp")
        XCTAssertEqual(fingerprint.urlParameters, ["k": "v"])
    }

    // MARK: - Revalidation Tests

    /// Helper to populate the cache with a v2 experience.
    /// Returns true if the fetch succeeded, false otherwise.
    private func populateCache(
        store: ExperienceStoreService,
        mockClient: MockFetchExperienceClient,
        url: URL,
        data: Data = ExperienceFixtures.simpleScreenJSON,
        urlParameters: [String: String] = [:]
    ) -> Bool {
        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return false
        }

        let downloadResult = ExperienceDownloadResult(
            data: data, version: "2", id: "test-exp", name: "Test", urlParameters: urlParameters)
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let fetchExpectation = expectation(description: "fetch completes")
        var succeeded = false
        store.fetchExperience(for: url) { result in
            if case .success = result { succeeded = true }
            fetchExpectation.fulfill()
        }
        waitForExpectations(timeout: 5)
        return succeeded
    }

    func testRevalidateReturnsUnchangedWhenNothingCached() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .unchanged = result {
                // expected
            } else {
                XCTFail("Expected .unchanged when nothing is cached")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testRevalidateReturnsUnchangedWhenContentIdentical() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Reset call counts after initial fetch
        mockClient.experienceDataTaskCallCount = 0
        mockClient.configurationTaskCallCount = 0

        // Revalidate with identical data
        let sameResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON, version: "2", id: "test-exp", name: "Test",
            urlParameters: [:])
        mockClient.experienceDataTaskHandler = { _ in .success(sameResult) }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .unchanged = result {
                // expected
            } else {
                XCTFail("Expected .unchanged when content is identical")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(
            mockClient.experienceDataTaskCallCount, 1,
            "Should have fetched document.json during revalidation")
        XCTAssertEqual(
            mockClient.configurationTaskCallCount, 0,
            "Should NOT have fetched configuration.json again when unchanged")
    }

    func testRevalidateReturnsFailureOnNetworkError() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Revalidate with network error
        mockClient.experienceDataTaskHandler = { _ in
            .failure(.networkError(URLError(.notConnectedToInternet)))
        }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .failure = result {
                // expected
            } else {
                XCTFail("Expected .failure on network error")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testRevalidateReturnsUpdatedWhenContentChanges() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Reset counts
        mockClient.experienceDataTaskCallCount = 0
        mockClient.configurationTaskCallCount = 0

        // Revalidate with different document content
        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }
        let updatedResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenUpdatedJSON,
            version: "2", id: "test-exp", name: "Test", urlParameters: [:])
        mockClient.experienceDataTaskHandler = { _ in .success(updatedResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .updated = result {
                // expected — content changed
            } else {
                XCTFail("Expected .updated when content has changed")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 1, "Should have fetched document.json")
        XCTAssertEqual(
            mockClient.configurationTaskCallCount, 1, "Should have fetched configuration.json for v2 update")
    }

    func testRevalidateReturnsUpdatedWhenParametersChange() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard populateCache(store: store, mockClient: mockClient, url: url, urlParameters: ["key": "value1"])
        else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Reset counts
        mockClient.configurationTaskCallCount = 0

        // Same document data but different Rover-Experience-Parameters
        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }
        let updatedResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2", id: "test-exp", name: "Test", urlParameters: ["key": "value2"])
        mockClient.experienceDataTaskHandler = { _ in .success(updatedResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .updated = result {
                // expected — parameters changed
            } else {
                XCTFail("Expected .updated when parameters have changed")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertEqual(
            mockClient.configurationTaskCallCount, 1, "Should have fetched configuration.json for v2 update")
    }

    func testRevalidateReturnsFailureWhenConfigFetchFails() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Content changed but configuration.json fetch fails
        let updatedResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenUpdatedJSON,
            version: "2", id: "test-exp", name: "Test", urlParameters: [:])
        mockClient.experienceDataTaskHandler = { _ in .success(updatedResult) }
        mockClient.configurationTaskHandler = { _ in .failure(.networkError(URLError(.timedOut))) }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .failure = result {
                // expected — config fetch failed
            } else {
                XCTFail("Expected .failure when configuration.json fetch fails")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    // MARK: - fetchExperience Tests

    func testFetchExperienceReturnsCachedExperienceOnCacheHit() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        // First fetch populates cache
        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Reset call counts
        mockClient.experienceDataTaskCallCount = 0
        mockClient.configurationTaskCallCount = 0

        // Second fetch should return cached result without network calls
        let exp = expectation(description: "second fetch completes")
        store.fetchExperience(for: url) { result in
            if case .success = result {
                // expected — cache hit
            } else {
                XCTFail("Expected success from cache")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 0, "Should not fetch when cached")
        XCTAssertEqual(mockClient.configurationTaskCallCount, 0, "Should not fetch config when cached")
    }

    func testFetchExperiencePopulatesCacheOnCacheMiss() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .success = result {
                // expected
            } else {
                XCTFail("Expected success on cache miss")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 1, "Should fetch document on cache miss")
        XCTAssertEqual(mockClient.configurationTaskCallCount, 1, "Should fetch config for v2 experience")
    }

    func testFetchExperienceStoresCorrectFingerprint() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        // Populate cache with specific data
        guard populateCache(store: store, mockClient: mockClient, url: url) else {
            XCTFail("Initial fetch must succeed")
            return
        }

        // Revalidate with identical content — should return .unchanged if fingerprint matches
        mockClient.experienceDataTaskCallCount = 0
        let sameResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(sameResult) }

        let exp = expectation(description: "revalidation completes")
        store.revalidateExperience(for: url) { result in
            if case .unchanged = result {
                // expected — fingerprint matches
            } else {
                XCTFail("Expected .unchanged when fingerprint matches, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testFetchExperienceDecodesV1ClassicExperience() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleClassicExperienceJSON,
            version: "1",
            id: "classic-exp-1",
            name: "Simple Classic Experience",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            switch result {
            case .success(let loaded):
                if case .classic(let experience, _) = loaded {
                    XCTAssertEqual(experience.id, "classic-exp-1")
                    XCTAssertEqual(experience.name, "Simple Classic Experience")
                } else {
                    XCTFail("Expected .classic case, got \(loaded)")
                }
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 1)
        XCTAssertEqual(mockClient.configurationTaskCallCount, 0, "v1 should not fetch CDN config")
    }

    func testFetchExperienceDecodesV2ModernExperience() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            switch result {
            case .success(let loaded):
                if case .standard = loaded {
                    // expected — v2 modern experience
                } else {
                    XCTFail("Expected .standard case for v2, got \(loaded)")
                }
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 1)
        XCTAssertEqual(mockClient.configurationTaskCallCount, 1, "v2 should fetch CDN config")
    }

    func testFetchExperienceReturnsFailureForUnsupportedVersion() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "99",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .failure(.unsupportedExperienceVersion(let version)) = result {
                XCTAssertEqual(version, "99")
            } else {
                XCTFail("Expected .unsupportedExperienceVersion, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testFetchExperienceReturnsFailureOnNetworkError() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        mockClient.experienceDataTaskHandler = { _ in
            .failure(.networkError(URLError(.notConnectedToInternet)))
        }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .failure(.networkError) = result {
                // expected
            } else {
                XCTFail("Expected .networkError, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testFetchExperienceReturnsFailureOnInvalidJSON() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        let downloadResult = ExperienceDownloadResult(
            data: invalidJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }

        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .failure(.invalidExperienceData) = result {
                // expected
            } else {
                XCTFail("Expected .invalidExperienceData, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testFetchExperienceReturnsFailureWhenV2ConfigFetchFails() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://example.com/experience")!

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }
        mockClient.configurationTaskHandler = { _ in .failure(.networkError(URLError(.timedOut))) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .failure(.networkError) = result {
                // expected — config fetch failure propagates
            } else {
                XCTFail("Expected .networkError from config fetch failure, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testFetchExperienceNormalizesDeepLinkToHTTPS() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        let store = ExperienceStoreService(client: mockClient, router: router)

        // Use a deep link scheme (rv-xxx:// is common for Rover deep links)
        let deepLinkURL = URL(string: "rv-example://example.com/experience")!

        guard let cdnConfig = try? CDNConfiguration(decode: ExperienceFixtures.cdnConfigurationJSON) else {
            XCTFail("Failed to decode CDN configuration fixture.")
            return
        }

        let downloadResult = ExperienceDownloadResult(
            data: ExperienceFixtures.simpleScreenJSON,
            version: "2",
            id: "test-exp",
            name: "Test",
            urlParameters: [:]
        )
        mockClient.experienceDataTaskHandler = { _ in .success(downloadResult) }
        mockClient.configurationTaskHandler = { _ in .success(cdnConfig) }

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: deepLinkURL) { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.lastExperienceDataTaskURL?.scheme, "https", "Deep link should be normalized to HTTPS")
        XCTAssertEqual(mockClient.lastExperienceDataTaskURL?.host, "example.com")
    }

    func testFetchExperienceReturnsFailureForInvalidDomain() {
        let mockClient = MockFetchExperienceClient()
        let router = MockRouter()
        router.isValidDomainHandler = { _ in false }  // Reject all domains
        let store = ExperienceStoreService(client: mockClient, router: router)
        let url = URL(string: "https://untrusted.com/experience")!

        let exp = expectation(description: "fetch completes")
        store.fetchExperience(for: url) { result in
            if case .failure(.networkError) = result {
                // expected — invalid domain returns networkError(nil)
            } else {
                XCTFail("Expected .networkError for invalid domain, got \(result)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(mockClient.experienceDataTaskCallCount, 0, "Should not attempt fetch for invalid domain")
    }
}

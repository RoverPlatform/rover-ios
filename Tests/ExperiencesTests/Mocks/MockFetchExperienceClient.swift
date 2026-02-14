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

import Foundation

@testable import RoverExperiences

private class NoOpURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {}
    override func stopLoading() {}
}

private let stubSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [NoOpURLProtocol.self]
    return URLSession(configuration: config)
}()

private let stubTaskURL = URL(string: "about:blank")!

class MockFetchExperienceClient: FetchExperienceClient {
    var experienceDataTaskHandler: ((URL) -> Result<ExperienceDownloadResult, Failure>)?
    var configurationTaskHandler: ((URL) -> Result<CDNConfiguration, Failure>)?
    var experienceDataTaskCallCount = 0
    var configurationTaskCallCount = 0
    var lastExperienceDataTaskURL: URL?

    func experienceDataTask(
        with url: URL,
        completionHandler: @escaping (Result<ExperienceDownloadResult, Failure>) -> Void
    ) -> URLSessionTask {
        experienceDataTaskCallCount += 1
        lastExperienceDataTaskURL = url
        let result = experienceDataTaskHandler?(url) ?? .failure(.networkError(nil))
        completionHandler(result)
        return stubSession.dataTask(with: stubTaskURL)
    }

    func configurationTask(
        with url: URL,
        completionHandler: @escaping (Result<CDNConfiguration, Failure>) -> Void
    ) -> URLSessionTask {
        configurationTaskCallCount += 1
        let result = configurationTaskHandler?(url) ?? .failure(.networkError(nil))
        completionHandler(result)
        return stubSession.dataTask(with: stubTaskURL)
    }
}

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
import os.log
import RoverData

protocol FetchExperienceClient {
    func experienceDataTask(with url: URL, completionHandler: @escaping (Result<ExperienceDownloadResult, Failure>) -> Void) -> URLSessionTask
    func configurationTask(with url: URL, completionHandler: @escaping (Result<CDNConfiguration, Failure>) -> Void) -> URLSessionTask
}
extension FetchExperienceClient {
    func dataResult(result: HTTPResult) -> Result<ExperienceDownloadResult, Failure> {
        switch result {
        case let .success(jsonData, urlResponse):
            let urlParams = getExperienceUrlParameters(urlResponse)
            let downloadResult = ExperienceDownloadResult(
                data: jsonData,
                version: urlResponse.value(forHTTPHeaderField: "Rover-Experience-Version") ?? "2",
                id: urlResponse.value(forHTTPHeaderField: "Rover-Experience-ID"),
                name: urlResponse.value(forHTTPHeaderField: "Rover-Experience-Name"),
                urlParameters: urlParams)
            return .success(downloadResult)
        case let .error(error, _):
            return .failure(.networkError(error))
        }
    }
    
    func configurationResult(result: HTTPResult) -> Result<CDNConfiguration, Failure> {
        switch result {
        case let .success(jsonData, _):
            do {
                let cdnConfiguration = try CDNConfiguration(decode: jsonData)
                rover_log(.info, "Configuration JSON has been retrieved.")
                return .success(cdnConfiguration)
            } catch {
                rover_log(.error, "Unable to retrieve Configuration JSON.")
                return .failure(.invalidResponseData(error, jsonData))
            }
            
        case let .error(error, _):
            rover_log(.error, "Unable to retrieve Configuration JSON.")
            return .failure(.networkError(error))
        }
    }
    
    func getExperienceUrlParameters(_ response: HTTPURLResponse) -> [String: String] {
        //get the parameters from the response.
        let requestParams = response.url?.query?.queryToDictionary() ?? [:]
        
        //get the parameters from the headers.
        let responseParams = response.value(forHTTPHeaderField: "Rover-Experience-Parameters")?.queryToDictionary() ?? [:]
        
        return requestParams.merging(responseParams) { (current, _) in current }
    }
}

// MARK: HTTPClient

extension HTTPClient: FetchExperienceClient {
    func experienceDataTask(with url: URL, completionHandler: @escaping (Result<ExperienceDownloadResult, Failure>) -> Void) -> URLSessionTask {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if url.lastPathComponent != "/document.json" {
            urlComponents.path = urlComponents.path.appending("/document.json")
        }

        let request = self.downloadRequest(url: urlComponents.url!)
        
        return self.downloadTask(with: request) { httpResult in
            let result = self.dataResult(result: httpResult)
            completionHandler(result)
        }
    }
    
    func configurationTask(with url: URL, completionHandler: @escaping (Result<CDNConfiguration, Failure>) -> Void) -> URLSessionTask {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.query = ""
        urlComponents.path = "/configuration.json"
        let request = self.downloadRequest(url: urlComponents.url!)
        
        return self.downloadTask(with: request) { httpResult in
            let result = self.configurationResult(result: httpResult)
            completionHandler(result)
        }
    }
}

enum Failure: LocalizedError {
    case emptyResponseData
    case invalidResponseData(Error, Data)
    case invalidStatusCode(Int)
    case networkError(Error?)
    case fileError(Error?)
    case unsupportedExperienceVersion(String)
    case invalidExperienceData
    
    var errorDescription: String? {
        switch self {
        case .emptyResponseData:
            return "Empty response data"
        case let .invalidResponseData(error, messageBody):
            return "Invalid response data: \(error.debugDescription), given message body: \(String(data: messageBody, encoding: .utf8) ?? "<binary>")"
        case let .invalidStatusCode(statusCode):
            return "Invalid status code: \(statusCode)"
        case let .networkError(error):
            if let error = error {
                return "Network error: \(error.debugDescription)"
            } else {
                return "Network error"
            }
        case let .fileError(error):
            if let error = error {
                return "File error: \(error.debugDescription)"
            } else {
                return "File error"
            }
        case let .unsupportedExperienceVersion(version):
            return "Version \(version) is unsupported"
        case .invalidExperienceData:
            return "Invalid experience data, unable to parse"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .emptyResponseData, .networkError:
            return true
        case .invalidResponseData,
                .invalidStatusCode,
                .fileError,
                .unsupportedExperienceVersion,
                .invalidExperienceData:
            return false
        }
    }
}

enum LoadedExperience {
    case classic(
        experience: ClassicExperienceModel,
        urlParameters: [String: String])
    case standard(
        experience: ExperienceModel,
        urlParameters: [String: String],
        userInfo: [String: Any],
        authorize: (inout URLRequest) -> Void)
}

struct ExperienceDownloadResult {
    let data: Data
    let version: String
    let id: String?
    let name: String?
    let urlParameters: [String: String]
}

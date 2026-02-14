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
import Foundation
import RoverData
import RoverFoundation
import RoverUI
import UIKit
import os.log

struct ExperienceFingerprint: Equatable {
    let dataHash: Data
    let version: String
    let id: String?
    let name: String?
    let urlParameters: [String: String]

    init(dataHash: Data, version: String, id: String?, name: String?, urlParameters: [String: String]) {
        self.dataHash = dataHash
        self.version = version
        self.id = id
        self.name = name
        self.urlParameters = urlParameters
    }

    init(from result: ExperienceDownloadResult) {
        self.dataHash = Data(SHA256.hash(data: result.data))
        self.version = result.version
        self.id = result.id
        self.name = result.name
        self.urlParameters = result.urlParameters
    }
}

class ExperienceStoreService: ExperienceStore {
    let client: FetchExperienceClient
    let router: Router
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "io.rover.sdk.fetchExperiences", attributes: .concurrent)

    init(client: FetchExperienceClient, router: Router) {
        self.client = client
        self.router = router
    }

    private class CacheKey: NSObject {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? CacheKey else {
                return false
            }

            let lhs = self
            return lhs.url == rhs.url
        }

        override var hash: Int {
            return url.hashValue
        }
    }

    private class CacheValue: NSObject {
        let experience: LoadedExperience
        let fingerprint: ExperienceFingerprint

        init(experience: LoadedExperience, fingerprint: ExperienceFingerprint) {
            self.experience = experience
            self.fingerprint = fingerprint
        }
    }

    private var cache = NSCache<CacheKey, CacheValue>()

    /// Return the experience for the given url from cache, provided that it has already been retrieved once
    /// in this session. Returns nil if the experience is not present in the cache.
    func experience(for url: URL) -> LoadedExperience? {
        let key = CacheKey(url: url)
        return cache.object(forKey: key)?.experience
    }

    /// Normalizes a URL for fetching (converts deep links to HTTPS) and validates the domain.
    /// Returns `nil` if the URL is invalid or the domain is not allowed.
    private func normalizedExperienceURL(for url: URL) -> URL? {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        urlComponents.scheme = "https"

        guard let experienceUrl = urlComponents.url else {
            return nil
        }

        guard router.isValidDomain(for: experienceUrl) else {
            return nil
        }

        return experienceUrl
    }

    /// Decodes a downloaded experience based on version and updates the cache.
    /// Calls the completion handler with the decoded experience or an error.
    private func decodeAndCache(
        downloadResult: ExperienceDownloadResult,
        experienceUrl: URL,
        cacheKey: CacheKey,
        completionHandler: @escaping (Result<LoadedExperience, Failure>) -> Void
    ) {
        let fingerprint = ExperienceFingerprint(from: downloadResult)

        switch downloadResult.version {
        case "1":
            let decodeResult = classicExperience(from: downloadResult, url: experienceUrl)
            switch decodeResult {
            case .success(let experience):
                let value = CacheValue(experience: experience, fingerprint: fingerprint)
                cache.setObject(value, forKey: cacheKey)
                completionHandler(.success(experience))
            case .failure(let error):
                completionHandler(.failure(.invalidExperienceData(error)))
            }

        case "2":
            let configTask = client.configurationTask(with: experienceUrl) { [weak self] cdnResult in
                guard let self else {
                    return
                }

                switch cdnResult {
                case .success(let cdnConfiguration):
                    let decodeResult = self.newExperience(
                        from: downloadResult, url: experienceUrl, configuration: cdnConfiguration)
                    switch decodeResult {
                    case .success(let experience):
                        let value = CacheValue(experience: experience, fingerprint: fingerprint)
                        self.cache.setObject(value, forKey: cacheKey)
                        completionHandler(.success(experience))
                    case .failure(let error):
                        completionHandler(.failure(.invalidExperienceData(error)))
                    }
                case .failure(let failure):
                    completionHandler(.failure(failure))
                }
            }
            configTask.resume()

        default:
            completionHandler(.failure(.unsupportedExperienceVersion(downloadResult.version)))
        }
    }

    /// Fetch an experience for the given identifier from Rover's servers.
    ///
    /// Before making a network request the experience store will first attempt to retreive the experience from
    /// its cache and will return the cache result if found.
    func fetchExperience(for url: URL, completionHandler: @escaping (Result<LoadedExperience, Failure>) -> Void) {
        if !Thread.isMainThread {
            os_log(
                "ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.",
                log: .rover, type: .default)
        }

        //if this is a file URL, load it right away.  Only new experiences can be loaded from file
        if url.isFileURL {
            do {
                if let experienceObj = try read(contentsOf: url) {
                    experienceObj.sourceUrl = url
                    let experience = LoadedExperience.file(
                        experience: experienceObj,
                        urlParameters: experienceObj.urlParameters,
                        userInfo: experienceObj.userInfo,
                        authorizers: experienceObj.getAuthorizers())
                    completionHandler(.success(experience))
                } else {
                    completionHandler(.failure(.fileError(nil)))
                }
            } catch {
                completionHandler(.failure(.fileError(error)))
            }
            return
        }

        guard let experienceUrl = normalizedExperienceURL(for: url) else {
            completionHandler(.failure(.networkError(nil)))
            return
        }

        //check the cache first before we load anything
        if let experience = experience(for: experienceUrl) {
            completionHandler(.success(experience))
            return
        }

        //download the experience
        let task = client.experienceDataTask(with: experienceUrl) { [self] result in
            switch result {
            case .failure(let error):
                os_log("Failed to fetch experience: %@", log: .rover, type: .error, error.debugDescription)
                completionHandler(.failure(error))
            case .success(let downloadResult):
                let key = CacheKey(url: experienceUrl)
                self.decodeAndCache(
                    downloadResult: downloadResult,
                    experienceUrl: experienceUrl,
                    cacheKey: key,
                    completionHandler: completionHandler
                )
            }
        }

        task.resume()
    }

    /// Revalidates a cached experience for the given URL.
    ///
    /// Normalizes the URL, verifies the domain, and compares the downloaded
    /// fingerprint to the cached one before updating the cache.
    ///
    /// Returns `.unchanged` when no cached experience exists or the
    /// fingerprint matches; `.updated` when new content is decoded and cached; and
    /// `.failure` for fetch or decode failures.
    func revalidateExperience(for url: URL, completionHandler: @escaping (RevalidationResult) -> Void) {
        if !Thread.isMainThread {
            os_log(
                "ExperienceStore is not thread-safe – revalidateExperience should only be called from main thread.",
                log: .rover, type: .default)
        }

        if url.isFileURL {
            // We should not be processing files
            completionHandler(.unchanged)
            return
        }

        guard let experienceUrl = normalizedExperienceURL(for: url) else {
            completionHandler(.failure(.networkError(nil)))
            return
        }

        // Nothing cached — nothing to compare against
        let key = CacheKey(url: experienceUrl)
        guard let cachedValue = cache.object(forKey: key) else {
            completionHandler(.unchanged)
            return
        }

        // Fetch fresh document.json
        let task = client.experienceDataTask(with: experienceUrl) { [self] result in
            switch result {
            case .failure(let failure):
                completionHandler(.failure(failure))
            case .success(let downloadResult):
                // Compare the cached fingerprint with the downloaded fingerprint to decide whether to update or not.
                let newFingerprint = ExperienceFingerprint(from: downloadResult)
                guard newFingerprint != cachedValue.fingerprint else {
                    completionHandler(.unchanged)
                    return
                }

                // Content changed — decode and update cache
                self.decodeAndCache(
                    downloadResult: downloadResult,
                    experienceUrl: experienceUrl,
                    cacheKey: key
                ) { result in
                    switch result {
                    case .success(let experience):
                        completionHandler(.updated(experience))
                    case .failure(let failure):
                        completionHandler(.failure(failure))
                    }
                }
            }
        }
        task.resume()
    }

    private func classicExperience(from result: ExperienceDownloadResult, url: URL?) -> Result<LoadedExperience, Error>
    {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)

            var experience = try decoder.decode(ClassicExperienceModel.self, from: result.data)
            experience.sourceUrl = url

            let returnValue = LoadedExperience.classic(
                experience: experience,
                urlParameters: result.urlParameters)
            return .success(returnValue)
        } catch {
            return .failure(error)
        }
    }

    private func newExperience(from result: ExperienceDownloadResult, url: URL, configuration: CDNConfiguration)
        -> Result<LoadedExperience, Error>
    {
        do {
            let assetContext = RemoteAssetContext(baseUrl: url, configuration: configuration)
            let experience = try ExperienceModel.decode(
                from: result.data,
                name: result.name,
                id: result.id,
                assetContext: assetContext)

            let urlParameters = result.urlParameters.merging(experience.urlParameters) { (current, _) in current }

            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = nil

            let queryParams = result.urlParameters.map { urlParameter in
                URLQueryItem(name: urlParameter.key, value: urlParameter.value)
            }

            if !queryParams.isEmpty {
                urlComponents?.queryItems = queryParams
            }

            experience.sourceUrl = urlComponents?.url

            return .success(
                LoadedExperience.standard(
                    experience: experience,
                    urlParameters: urlParameters))
        } catch {
            return .failure(error)
        }
    }
}

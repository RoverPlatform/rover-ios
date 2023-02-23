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
import RoverFoundation
import RoverData
import UIKit
import RoverUI

class ExperienceStoreService: ExperienceStore {
    let client: FetchExperienceClient
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "io.rover.sdk.fetchExperiences", attributes: .concurrent)
    
    init(client: FetchExperienceClient) {
        self.client = client
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
        
        init(experience: LoadedExperience) {
            self.experience = experience
        }
    }
    
    private var cache = NSCache<CacheKey, CacheValue>()
    
    /// Return the experience for the given url from cache, provided that it has already been retrieved once
    /// in this session. Returns nil if the experience is not present in the cache.
    func experience(for url: URL) -> LoadedExperience? {
        let key = CacheKey(url: url)
        return cache.object(forKey: key)?.experience
    }
    
    /// Fetch an experience for the given identifier from Rover's servers.
    ///
    /// Before making a network request the experience store will first attempt to retreive the experience from
    /// its cache and will return the cache result if found.
    func fetchExperience(for url: URL, completionHandler: @escaping (Result<LoadedExperience, Failure>) -> Void) {
        if !Thread.isMainThread {
            os_log("ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.", log: .rover, type: .default)
        }
        
        //if this is a file URL, load it right away.  Only new experiences can be loaded from file
        if url.isFileURL {
            do {
                if let experienceObj = try read(contentsOf: url) {
                    let experience = LoadedExperience.standard(
                        experience: experienceObj,
                        urlParameters: experienceObj.urlParameters,
                        userInfo: experienceObj.userInfo,
                        authorize: experienceObj.authorize(_:))
                    completionHandler(.success(experience))
                } else {
                    completionHandler(.failure(.fileError(nil)))
                }
            } catch {
                completionHandler(.failure(.fileError(error)))
            }
            return
        }
        
        // Convert experience deep links to HTTPS so they can be loaded.
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        urlComponents.scheme = "https"

        guard let experienceUrl = urlComponents.url else {
            return
        }
        
        //check the domain of the url against the listed associated domains
        let router = Rover.shared.resolve(Router.self)!
        
        guard router.isValidDomain(for: experienceUrl) else {
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
            case let .failure(error):
                os_log("Failed to fetch experience: %@", log: .rover, type: .error, error.debugDescription)
                completionHandler(.failure(error))
            case let .success(downloadResult):
                switch downloadResult.version {
                case "1":
                    guard let experience = classicExperience(from: downloadResult) else {
                        completionHandler(.failure(.invalidExperienceData))
                        return
                    }
                    let key = CacheKey(url: experienceUrl)
                    let value = CacheValue(experience: experience)
                    self.cache.setObject(value, forKey: key)
                    completionHandler(.success(experience))
                    
                case "2":
                    let configurationTask = client.configurationTask(with: experienceUrl) { [self] cdnResult in
                        switch cdnResult {
                        case let .success(cdnConfiguration):
                            guard let experience = newExperience(from: downloadResult, url: experienceUrl, configuration: cdnConfiguration) else {
                                completionHandler(.failure(.invalidExperienceData))
                                return
                            }
                            let key = CacheKey(url: experienceUrl)
                            let value = CacheValue(experience: experience)
                            self.cache.setObject(value, forKey: key)
                            completionHandler(.success(experience))
                            
                        case let .failure(failure):
                            completionHandler(.failure(failure))
                        }
                    }
                    configurationTask.resume()
                default:
                    completionHandler(.failure(.unsupportedExperienceVersion(downloadResult.version)))
                }
            }
        }

        task.resume()
    }
    
    private func classicExperience(from result: ExperienceDownloadResult) -> LoadedExperience? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
            
            let experience = try decoder.decode(ClassicExperienceModel.self, from: result.data)
            let returnValue = LoadedExperience.classic(
                experience: experience,
                urlParameters: result.urlParameters)
            return returnValue
        } catch {
            return nil
        }
    }
    
    private func newExperience(from result: ExperienceDownloadResult, url: URL, configuration: CDNConfiguration) -> LoadedExperience? {
        do {
            let assetContext = RemoteAssetContext(baseUrl: url, configuration: configuration)
            let experience = try ExperienceModel.decode(
                from: result.data,
                name: result.name,
                id: result.id,
                assetContext: assetContext)
            let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
            
            let urlParameters = result.urlParameters.merging(experience.urlParameters) { (current, _) in current }
            
            return LoadedExperience.standard(
                experience: experience,
                urlParameters: urlParameters,
                userInfo: experienceManager.userInfo,
                authorize: experienceManager.authorize(_:))
        } catch {
            return nil
        }
    }
}

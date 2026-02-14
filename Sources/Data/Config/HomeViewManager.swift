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
import UIKit
import os.log

/// Manager for the Hub home view experience URL.
///
/// Fetches the home view URL from the `/home` endpoint, caches the response in
/// UserDefaults, and publishes changes for SwiftUI observation. The cached value is
/// loaded during initialization so the most recent URL is available immediately.
///
/// **Fetch strategy:** Requests include the most specific available identifier
/// (user ID, Ticketmaster ID, SeatGeek ID, then device identifier). On success, the
/// response is persisted and published; on failure, the cached value is preserved.
///
/// - SeeAlso: `ConfigManager` for the configuration caching pattern.
@MainActor
public class HomeViewManager: ObservableObject {
    /// The currently available home view experience URL.
    ///
    /// Returns the most recent successful fetch result or the cached value loaded from
    /// UserDefaults during initialization. A `nil` value indicates no home view.
    @Published public private(set) var experienceURL: URL?

    private let httpClient: HTTPClient
    private let userDefaults: UserDefaults
    private let userInfoManager: UserInfoManager

    private static let storageKey = "io.rover.homeView.response"

    /// Creates a new home view manager.
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client used to fetch from the `/home` endpoint.
    ///   - userDefaults: The UserDefaults instance for caching the URL.
    ///   - userInfoManager: The user info manager for resolving user identity.
    public init(httpClient: HTTPClient, userDefaults: UserDefaults, userInfoManager: UserInfoManager) {
        self.httpClient = httpClient
        self.userDefaults = userDefaults
        self.userInfoManager = userInfoManager
        self.experienceURL = loadCachedResponse()?.experienceURL
    }

    /// Fetches the home view URL from the `/home` endpoint.
    ///
    /// On success, the response is cached and `experienceURL` is updated if the value
    /// changed. On failure, the cached value is preserved.
    public func fetch() async {
        let identifier = resolveIdentifier()
        let result = await httpClient.getHomeView(identifier: identifier)
        switch result {
        case .success(let response):
            if experienceURL != response.experienceURL {
                experienceURL = response.experienceURL
            }
            saveToCache(response)
            os_log(.debug, log: .homeView, "Home view URL fetched successfully")
        case .failure(let error):
            // Silent failure - preserve cached URL
            os_log(
                .error, log: .homeView, "Failed to fetch home view URL: %@",
                error.localizedDescription)
        }
    }

    private func resolveIdentifier() -> HomeViewIdentifier {
        let userInfo = userInfoManager.currentUserInfo

        if let userID = userInfo["userID"] as? String, !userID.isEmpty {
            return .userID(userID)
        }

        if let ticketmasterID = userInfo["ticketmaster.ticketmasterID"] as? String,
            !ticketmasterID.isEmpty
        {
            return .userID(ticketmasterID)
        }

        if let seatGeekID = userInfo["seatGeek.seatGeekID"] as? String,
            !seatGeekID.isEmpty
        {
            return .userID(seatGeekID)
        }

        guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else {
            os_log(.error, log: .homeView, "Device identifier unavailable")
            return .deviceIdentifier("")
        }
        return .deviceIdentifier(deviceID)
    }

    private func loadCachedResponse() -> HomeViewResponse? {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(HomeViewResponse.self, from: data)
    }

    private func saveToCache(_ response: HomeViewResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}

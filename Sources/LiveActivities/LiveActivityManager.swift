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

import ActivityKit
import Foundation
import RoverData
import RoverFoundation
import os.log

class LiveActivityManager {
    let persistedTokens = PersistedValue<[Context.LiveActivityToken]>(
        storageKey: "io.rover.RoverLiveActivity.tokens"
    )

    /// Running observation tasks for push to start tokens, keyed by the Activity name.
    private var pushToStartTasks: [String: Task<Void, Never>] = [:]

    /// Serial queue to synchronize access to persistedTokens
    private let tokenSyncQueue = DispatchQueue(label: "io.rover.RoverLiveActivity.tokenSync")

    deinit {
        pushToStartTasks.values.forEach { $0.cancel() }
    }
}

// MARK: LiveActivityService

extension LiveActivityManager: LiveActivityService {
    @discardableResult
    func registerLiveActivity<T: ActivityAttributes>(
        attributes: T.Type,
        name: String
    ) -> Task<Void, Never> {
        guard #available(iOS 18.0, *) else {
            os_log(.info, "Rover Live Activities only supported on iOS 18.0 or later.")
            return Task {}
        }

        pushToStartTasks[name]?.cancel()

        let task = Task { [weak self] in
            defer {
                self?.pushToStartTasks.removeValue(forKey: name)
            }

            // Push-to-start live activities: this stream produces the token you send to your server so it can
            // start new Live Activities via APNs.
            //
            // Note that this is not the same token used to *update* a specific running Activity. We update those only with channels.
            for await data in Activity<T>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { return }
                let tokenString = data.map { String(format: "%02x", $0) }.joined()
                os_log(
                    "Received push-to-start token for %{public}@: %{private}@",
                    log: .liveActivity,
                    type: .debug,
                    name,
                    tokenString
                )
                let pushToken = Context.PushToken(value: tokenString, timestamp: Date())
                self?.updateToken(
                    name: name,
                    pushToStartToken: pushToken
                )
            }
        }
        pushToStartTasks[name] = task
        return task
    }


    func registerToken(
        name: String,
        pushToStartToken: Context.PushToken?,
    ) {
        updateToken(
            name: name,
            pushToStartToken: pushToStartToken
        )
    }

    func removeToken(name: String) {
        tokenSyncQueue.sync {
            var tokens = persistedTokens.value ?? []
            tokens.removeAll { $0.name == name }
            persistedTokens.value = tokens.isEmpty ? nil : tokens
        }

        pushToStartTasks[name]?.cancel()
        pushToStartTasks.removeValue(forKey: name)
    }
}

// MARK: LiveActivityTokensContextProvider

extension LiveActivityManager: LiveActivityTokensContextProvider {
    var liveActivityTokens: [Context.LiveActivityToken]? {
        return tokenSyncQueue.sync {
            return persistedTokens.value
        }
    }
}

// MARK: Private

extension LiveActivityManager {
    fileprivate func updateToken(
        name: String,
        pushToStartToken: Context.PushToken?,
    ) {
        tokenSyncQueue.sync {
            var tokens = persistedTokens.value ?? []

            if let index = tokens.firstIndex(where: { $0.name == name }) {
                var existing = tokens[index]
                if let ptsToken = pushToStartToken {
                    existing.pushToStartToken = ptsToken
                }
                tokens[index] = existing
            } else {
                let newToken = Context.LiveActivityToken(
                    name: name,
                    pushToStartToken: pushToStartToken
                )
                tokens.append(newToken)
            }

            // apply the update
            self.persistedTokens.value = tokens
        }
    }
}

// MARK: os.log extension

extension OSLog {
    fileprivate static let liveActivity = OSLog(
        subsystem: "io.rover.RoverLiveActivity",
        category: "LiveActivity"
    )
}

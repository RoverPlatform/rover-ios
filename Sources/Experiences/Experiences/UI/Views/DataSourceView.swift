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
import SwiftUI

struct DataSourceView: View {
    var dataSource: RoverExperiences.DataSource
    var dataSourceUrlString: String? {
        return dataSource.url.evaluatingExpressions(
            data: parentData,
            urlParameters: urlParameters,
            userInfo: userInfo,
            deviceContext: deviceContext
        )
    }

    @Environment(\.data) private var parentData
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.authorizers) private var authorizers
    @Environment(\.experienceManager) private var experienceManager

    // Fetched data
    @State private var fetchedData: Any??

    // What `fetchedData` was fetched for, so reappearing waits for the next poll instead of refetching.
    @State private var fetchedKey: FetchKey?

    // Bumped by pull to refresh, which restarts the fetch loop.
    @State private var refreshGeneration = 0

    var body: some View {
        let key = fetchKey
        content
            .onReceive(dataSource.objectWillChange) {
                refreshGeneration += 1
            }
            .task(id: key) {
                await poll(key)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let fetchedData = fetchedData {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .environment(\.data, fetchedData)
        } else {
            redactedView
        }
    }

    private var fetchKey: FetchKey? {
        guard let urlString = dataSourceUrlString, let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = dataSource.httpMethod.rawValue

        request.httpBody = dataSource.httpBody?
            .evaluatingExpressions(
                data: parentData,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            )?
            .data(using: .utf8)

        request.allHTTPHeaderFields = dataSource.headers.reduce(nil) { result, header in
            guard
                let value = header.value.evaluatingExpressions(
                    data: parentData,
                    urlParameters: urlParameters,
                    userInfo: userInfo,
                    deviceContext: deviceContext
                )
            else {
                return result
            }

            var nextResult = result ?? [:]
            nextResult[header.key] = value
            return nextResult
        }

        return FetchKey(request: request, generation: refreshGeneration)
    }

    /// Fetches, then refetches every `pollInterval` seconds until SwiftUI cancels the task.
    ///
    /// Each poll waits for the previous fetch to finish, so fetches never overlap.
    @MainActor
    private func poll(_ key: FetchKey?) async {
        guard let key else {
            return
        }

        if fetchedKey != key {
            await fetch(key)
        }

        guard let pollInterval = dataSource.pollInterval else {
            return
        }

        // At least a second, so a zero or negative interval cannot refetch a failing endpoint
        // back to back.
        let interval = max(pollInterval, 1)

        while (try? await Task.sleep(for: .seconds(interval))) != nil {
            await fetch(key)
        }
    }

    /// Checks for cancellation between stages, so a view that has gone or changed request does not
    /// go on to run authorizers or send a request it no longer wants.
    @MainActor
    private func fetch(_ key: FetchKey) async {
        guard !Task.isCancelled else {
            return
        }

        var request = await experienceManager!.authContext.authenticateRequest(request: key.request)
        guard !Task.isCancelled else {
            return
        }

        await authorizers.authorize(&request)
        guard !Task.isCancelled else {
            return
        }

        guard case .success(let fetchedData) = await URLSession.shared.fetchJSON(for: request), !Task.isCancelled else {
            return
        }

        self.fetchedData = fetchedData
        self.fetchedKey = key
    }

    private var layers: [Layer] {
        dataSource.children.compactMap { $0 as? Layer }
    }

    @ViewBuilder
    private var redactedView: some View {
        ForEach(layers) {
            LayerView(layer: $0)
        }
        .redacted(reason: .placeholder)
    }
}

private struct FetchKey: Equatable {
    var request: URLRequest
    var generation: Int

    // `URLRequest` equality ignores `httpBody`, so a body interpolated from parent data would
    // otherwise keep polling with its first value.
    static func == (lhs: FetchKey, rhs: FetchKey) -> Bool {
        lhs.request == rhs.request && lhs.request.httpBody == rhs.request.httpBody
            && lhs.generation == rhs.generation
    }
}

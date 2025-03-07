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


import Combine
import SwiftUI
import RoverFoundation
import os.log

@MainActor
struct DataSourceViewFdsaf: View {
    var dataSource: RoverExperiences.DataSource
    var dataSourceUrlString: String? {
        get {
            return dataSource.url.evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext)
        }
    }
    
    @Environment(\.data) private var parentData
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.authorizers) private var authorizers
    
    @State private var cancellables: Set<AnyCancellable> = []
    
    // Fetched data
    @State private var fetchedData: Any??
    
    var body: some View {
        content
    }
    
    @ViewBuilder
    var content: some View {
        if let fetchedData = fetchedData {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .environment(\.data, fetchedData)
        } else {
            redactedView
        }
    }
    
    private var layers: [Layer] {
        dataSource.children.compactMap { $0 as? Layer }
    }
    
    @ViewBuilder
    private var redactedView: some View {
        if #available(iOS 14.0, *) {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .redacted(reason: .placeholder)
            .onAppear { print("BUT THIS WORKS OLOLOL?")}
            .task {
                while(true) {
                    do {
                        fetchedData = try await fetchData()
                    } catch {
                        // do nothing, and fallthrough to polling below
                        os_log(.error, "Error fetching data source: %s", error.localizedDescription)
                    }
                    
                    if let pollInterval = dataSource.pollInterval {
                        do {
                            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                        } catch {
                            // task cancelled
                            break
                        }
                    } else {
                        break
                    }
                }
            }
        } else {
            // TODO: Anything better we can do here?
            EmptyView()
        }
    }
    
    // let's make this async.
    
    private func fetchData() async throws -> Any? {
        guard let urlString = dataSourceUrlString,
              let url = URL(string: urlString) else {
            throw UnableToInterpolateDataSourceURLError()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = dataSource.httpMethod.rawValue
        
        // Configure request body
        request.httpBody = dataSource.httpBody?
            .evaluatingExpressions(
                data: parentData,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            )?
            .data(using: .utf8)
        
        // Configure headers
        request.allHTTPHeaderFields = dataSource.headers.reduce(into: [:]) { headers, header in
            guard let value = header.value.evaluatingExpressions(
                data: parentData,
                urlParameters: urlParameters,
                userInfo: userInfo,
                deviceContext: deviceContext
            ) else { return }
            
            headers[header.key] = value
        }
        
        // TODO: do async thing to inject the ID Token Auth header.
        
        
        // but I guess the next thing to do I decide where the Auth state stuff is going to live. look through the SDK to see what the pattern is.
        
        
        // Authorization
        await authorizers.authorize(&request)
        
        // Network call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Parse JSON (optional based on your needs)
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
}





struct DataSourceViewAsyncTask: View {
    var dataSource: RoverExperiences.DataSource
    var dataSourceUrlString: String? {
        get {
            return dataSource.url.evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext)
        }
    }
    
    @Environment(\.data) private var parentData
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.authorizers) private var authorizers
    
    @State private var cancellables: Set<AnyCancellable> = []
    
    // Fetched data
    @State private var fetchedData: Any??
    
    // Autorefresh timer
    @State private var refreshTimer: Timer?
    
    @ViewBuilder
    var body: some View {
        if let fetchedData = fetchedData {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .environment(\.data, fetchedData)
            .onReceive(dataSource.objectWillChange) {
                cancellables.removeAll()
                publisher.sink { result in
                    guard case let Result.success(fetchedData) = result else {
                        return
                    }
                    self.fetchedData = fetchedData
                }.store(in: &cancellables)
            }
            .onDisappear() {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            .onAppear() {
                setRefreshTimer()
            }
        } else {
            redactedView
                .onReceive(publisher) { result in
                    guard case let Result.success(fetchedData) = result else {
                        return
                    }
                    
                    setRefreshTimer()
                    
                    self.fetchedData = fetchedData
                }
        }
    }

    
    private var publisher: AnyPublisher<Result<Any?, Error>, Never> {
        guard let urlString = dataSourceUrlString, let url = URL(string: urlString) else {
            return Just(Result.failure(UnableToInterpolateDataSourceURLError())).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = dataSource.httpMethod.rawValue
        
        request.httpBody = dataSource.httpBody?
            .evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext)?
            .data(using: .utf8)
        
        request.allHTTPHeaderFields = dataSource.headers.reduce(nil) { result, header in
            guard let value = header.value.evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext) else {
                return result
            }
            
            var nextResult = result ?? [:]
            nextResult[header.key] = value
            return nextResult
        }
        
        return authorizers.authorizePublisher(request).flatMap { request in
            URLSession.shared.dataPublisher(for: request)
        }.eraseToAnyPublisher()
    }
    
    private var layers: [Layer] {
        dataSource.children.compactMap { $0 as? Layer }
    }
    
    @ViewBuilder
    private var redactedView: some View {
        if #available(iOS 14.0, *) {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .redacted(reason: .placeholder)
        } else {
            // TODO: Anything better we can do here?
            EmptyView()
        }
    }
    
    private func setRefreshTimer() {
        if let pollInterval = dataSource.pollInterval, refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollInterval), repeats:true ) { _ in
                dataSource.objectWillChange.send()
            }
        }
    }
}


// OK can't use .task { } because of the nuanced empty case. Let's keep the current implementation, which works and also handles cancellation, and just wrap the Swift concurrency stuff in Combine publishers. START HERE i guess.


struct DataSourceView: View {
    var dataSource: RoverExperiences.DataSource
    var dataSourceUrlString: String? {
        get {
            return dataSource.url.evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext)
        }
    }
    
    @Environment(\.data) private var parentData
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.authorizers) private var authorizers
    @Environment(\.experienceManager) private var experienceManager
    
    @State private var cancellables: Set<AnyCancellable> = []
    
    // Fetched data
    @State private var fetchedData: Any??
    
    // Autorefresh timer
    @State private var refreshTimer: Timer?
    
    @ViewBuilder
    var body: some View {
        if let fetchedData = fetchedData {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .environment(\.data, fetchedData)
            .onReceive(dataSource.objectWillChange) {
                cancellables.removeAll()
                publisher.sink { result in
                    guard case let Result.success(fetchedData) = result else {
                        return
                    }
                    self.fetchedData = fetchedData
                }.store(in: &cancellables)
            }
            .onDisappear() {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            .onAppear() {
                setRefreshTimer()
            }
        } else {
            redactedView
                .onReceive(publisher) { result in
                    guard case let Result.success(fetchedData) = result else {
                        return
                    }
                    
                    setRefreshTimer()
                    
                    self.fetchedData = fetchedData
                }
        }
    }

    
    private var publisher: AnyPublisher<Result<Any?, Error>, Never> {
        guard let urlString = dataSourceUrlString, let url = URL(string: urlString) else {
            return Just(Result.failure(UnableToInterpolateDataSourceURLError())).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = dataSource.httpMethod.rawValue
        
        request.httpBody = dataSource.httpBody?
            .evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext)?
            .data(using: .utf8)
        
        request.allHTTPHeaderFields = dataSource.headers.reduce(nil) { result, header in
            guard let value = header.value.evaluatingExpressions(data: parentData, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext) else {
                return result
            }
            
            var nextResult = result ?? [:]
            nextResult[header.key] = value
            return nextResult
        }
        
        return TaskPublisher {
            await experienceManager!.authContext.authenticateRequest(request: request)
        }.flatMap { request in
            authorizers.authorizePublisher(request)
        }.flatMap { request in
            URLSession.shared.dataPublisher(for: request)
        }.catch({ error in
            return Just(Result<Any?, Error>.failure(error))
        })
        .eraseToAnyPublisher()
    }
    
    private var layers: [Layer] {
        dataSource.children.compactMap { $0 as? Layer }
    }
    
    @ViewBuilder
    private var redactedView: some View {
        if #available(iOS 14.0, *) {
            ForEach(layers) {
                LayerView(layer: $0)
            }
            .redacted(reason: .placeholder)
        } else {
            // TODO: Anything better we can do here?
            EmptyView()
        }
    }
    
    private func setRefreshTimer() {
        if let pollInterval = dataSource.pollInterval, refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollInterval), repeats:true ) { _ in
                dataSource.objectWillChange.send()
            }
        }
    }
}

private struct UnableToInterpolateDataSourceURLError: Error {
    var errorDescription: String {
        "Unable to evaluate expressions in Data Source URL"
    }
}

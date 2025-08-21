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

import UIKit
import os.log

/// A service that coordinates syncs between the app and the server, with special support for participants in the single batched GraphQL sync endpoint.
class SyncCoordinatorService: SyncCoordinator {
  let client: SyncClient

  private var syncTask: Task<UIBackgroundFetchResult, Never>?
  private var willEnterForegroundObserver: NSObjectProtocol?

  var participants = [SyncParticipant]()
  var standaloneParticipants = [SyncStandaloneParticipant]()

  init(client: SyncClient) {
    self.client = client

    // Observe app entering foreground to trigger automatic sync
    self.willEnterForegroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: OperationQueue.main
    ) { [weak self] _ in
      self?.sync()
    }
  }

  func registerStandaloneParticipant(_ participant: SyncStandaloneParticipant) {
    standaloneParticipants.append(participant)
  }

  func sync(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

    var initialParticipants = [SyncParticipant]()
    var initialRequests = [SyncRequest]()

    for participant in self.participants {
      if let request = participant.initialRequest() {
        initialParticipants.append(participant)
        initialRequests.append(request)
      }
    }

    os_log(
      "SyncCoordinator beginning sync for participants: %@, standalone participants: %@",
      log: .sync, type: .info,
      initialParticipants.map { String(describing: type(of: $0)) }.joined(separator: ", "),
      standaloneParticipants.map { String(describing: type(of: $0)) }.joined(separator: ", "))

    self.sync(
      participants: initialParticipants, requests: initialRequests,
      completionHandler: completionHandler)
  }

  func syncAsync() async {
    await performAsyncSync()
  }

  func sync(
    participants: [SyncParticipant], requests: [SyncRequest],
    completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil
  ) {
    Task {
      let result: UIBackgroundFetchResult

      if let existingTask = self.syncTask {
        os_log("Sync already in-progress, waiting for completion", log: .sync, type: .debug)
        result = await existingTask.value
      } else {
        self.syncTask = Task {
          let syncResult = await performAsyncSync(participants: participants, requests: requests)
          await MainActor.run {
            self.syncTask = nil
          }
          return syncResult
        }
        result = await self.syncTask!.value
      }

      completionHandler?(result)
    }
  }

  @discardableResult
  private func performAsyncSync(participants: [SyncParticipant] = [], requests: [SyncRequest] = [])
    async -> UIBackgroundFetchResult
  {
    let initialParticipants = participants.isEmpty ? getInitialParticipants() : participants
    let initialRequests = requests.isEmpty ? getInitialRequests() : requests

    // Run GraphQL sync and standalone sync concurrently, ensuring standalone always runs
    async let graphqlResult = syncGraphQLParticipants(
      participants: initialParticipants, requests: initialRequests)
    async let standaloneResult = syncStandaloneParticipants()

    let (graphqlHadNewData, standaloneHadNewData) = await (graphqlResult, standaloneResult)

    os_log("Rover sync completed", log: .sync, type: .info)

    if graphqlHadNewData || standaloneHadNewData {
      return .newData
    } else {
      return .noData
    }
  }

  private func getInitialParticipants() -> [SyncParticipant] {
    return participants.compactMap { participant in
      return participant.initialRequest() != nil ? participant : nil
    }
  }

  private func getInitialRequests() -> [SyncRequest] {
    return participants.compactMap { participant in
      return participant.initialRequest()
    }
  }

  private func syncGraphQLParticipants(participants: [SyncParticipant], requests: [SyncRequest])
    async -> Bool
  {
    guard !participants.isEmpty && !requests.isEmpty else {
      return false
    }

    var currentParticipants = participants
    var currentRequests = requests
    var hasNewData = false

    repeat {
      do {
        let data = try await client.sync(with: currentRequests)

        var nextParticipants = [SyncParticipant]()
        var nextRequests = [SyncRequest]()

        for participant in currentParticipants {
          let result = participant.saveResponse(data)

          switch result {
          case .newData(let nextRequest):
            hasNewData = true
            if let nextRequest = nextRequest {
              nextParticipants.append(participant)
              nextRequests.append(nextRequest)
            }
          case .noData:
            break
          case .failed:
            os_log("GraphQL participant failed to process response", log: .sync, type: .error)
            break
          }
        }

        currentParticipants = nextParticipants
        currentRequests = nextRequests

      } catch {
        os_log("GraphQL sync failed: %@", log: .sync, type: .error, error.localizedDescription)
        return hasNewData
      }
    } while !currentParticipants.isEmpty && !currentRequests.isEmpty

    return hasNewData
  }

  private func syncStandaloneParticipants() async -> Bool {
    var hasNewData = false

    for participant in standaloneParticipants {
      let success = await participant.sync()
      if success {
        hasNewData = true
      }
    }

    return hasNewData
  }

  deinit {
    if let observer = willEnterForegroundObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

}

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

/// Wrap a Swift Concurrency task in a Combine publisher.
struct TaskPublisher<Output>: Publisher {
    typealias Failure = Error
    
    private let task: () async throws -> Output
    
    init(task: @escaping () async throws -> Output) {
        self.task = task
    }
    
    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = TaskSubscription(subscriber: subscriber, task: task)
        subscriber.receive(subscription: subscription)
    }
}

private final class TaskSubscription<S: Subscriber, Output>: Subscription
where S.Input == Output, S.Failure == Error {
    private var subscriber: S?
    private var task: Task<Void, Never>?
    private let work: () async throws -> Output
    
    init(subscriber: S, task: @escaping () async throws -> Output) {
        self.subscriber = subscriber
        self.work = task
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand > 0 else { return }
        
        task = Task { [weak self] in
            do {
                guard !Task.isCancelled, let self else { return }
                let result = try await self.work()
                _ = self.subscriber?.receive(result)
                self.subscriber?.receive(completion: .finished)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.subscriber?.receive(completion: .failure(error))
            }
            self?.task = nil
        }
    }
    
    func cancel() {
        task?.cancel()
        subscriber = nil
    }
}

//
//  EventQueue.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-09-01.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

public class EventQueue {
    let client: EventsClient
    let flushAt: Int
    let flushInterval: Double
    let maxBatchSize: Int
    let maxQueueSize: Int
    
    // swiftlint:disable:next implicitly_unwrapped_optional // Use an implicitly unwrapped optional to allow circular dependency injection
    var contextProvider: ContextProvider!
    
    let serialQueue: Foundation.OperationQueue = {
        let q = Foundation.OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    struct WeakObserver {
        private(set) weak var value: EventQueueObserver?
        
        init(_ value: EventQueueObserver) {
            self.value = value
        }
    }
    
    var observers = [WeakObserver]()
    
    // The following variables comprise the state of the EventQueueService and should only be modified from within an operation on the serial queue
    
    var eventQueue = [Event]()
    var uploadTask: URLSessionTask?
    var timer: Timer?
    
    var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    var cache: URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("events").appendingPathExtension("plist")
    }
    
    var didBecomeActiveObserver: NSObjectProtocol?
    var willResignActiveObserver: NSObjectProtocol?
    var didEnterBackgroundObserver: NSObjectProtocol?
    
    init(client: EventsClient, flushAt: Int, flushInterval: Double, maxBatchSize: Int, maxQueueSize: Int) {
        self.client = client
        self.flushAt = flushAt
        self.flushInterval = flushInterval
        self.maxBatchSize = maxBatchSize
        self.maxQueueSize = maxQueueSize
    }
    
    public func restore() {
        restoreEvents()
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.startTimer()
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.stopTimer()
        }
        
        self.didEnterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.beginBackgroundTask()
            self?.flushEvents()
        }
        
        if UIApplication.shared.applicationState == .active {
            self.startTimer()
        }
    }
    
    deinit {
        self.stopTimer()
        
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        
        if let didEnterBackgroundObserver = self.didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver)
        }
    }
    
    func restoreEvents() {
        serialQueue.addOperation {
            os_log("Restoring events from cache...", log: .events, type: .debug)
            
            guard let cache = self.cache else {
                os_log("Cache not found", log: .events, type: .error)
                return
            }
            
            if !FileManager.default.fileExists(atPath: cache.path) {
                os_log("Cache is empty, no events to restore", log: .events, type: .debug)
                return
            }
            
            do {
                let data = try Data(contentsOf: cache)
                self.eventQueue = try PropertyListDecoder().decode([Event].self, from: data)
                os_log("%d event(s) restored from cache", log: .events, type: .debug, self.eventQueue.count)
            } catch {
                os_log("Failed to restore events from cache: %@", log: .events, type: .error, error.logDescription)
            }
        }
    }
    
    public func addEvent(_ info: EventInfo) {
        let context = self.contextProvider.context
        
        serialQueue.addOperation {
            if self.eventQueue.count == self.maxQueueSize {
                os_log("Event queue is at capacity (%d) – removing oldest event", log: .events, type: .debug, self.maxQueueSize)
                self.eventQueue.remove(at: 0)
            }
            
            let event = Event(
                name: info.name,
                context: context,
                namespace: info.namespace,
                attributes: info.attributes,
                timestamp: info.timestamp ?? Date()
            )
            
            self.eventQueue.append(event)
            os_log("Added event to queue: %@", log: .events, type: .debug, event.name)
            os_log("Queue now contains %d event(s)", log: .events, type: .debug, self.eventQueue.count)
        }
        
        persistEvents()
        
        let onMainThread: (() -> Void) -> Void = { block in
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.sync {
                    block()
                }
            }
        }
        
        onMainThread {
            if UIApplication.shared.applicationState == .active {
                flushEvents(minBatchSize: flushAt)
            } else {
                flushEvents()
            }
        }
        
        observers.compactMap { $0.value }.forEach { $0.eventQueue(self, didAddEvent: info) }
    }
    
    func persistEvents() {
        serialQueue.addOperation {
            os_log("Persisting events to cache...", log: .events, type: .debug)
            
            guard let cache = self.cache else {
                os_log("Cache not found", log: .events, type: .error)
                return
            }
            
            do {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .xml
                let data = try encoder.encode(self.eventQueue)
                try data.write(to: cache, options: [.atomic])
                os_log("Cache now contains %d event(s)", log: .events, type: .debug, self.eventQueue.count)
            } catch {
                os_log("Failed to persist events to cache: %@", log: .events, type: .error, error.logDescription)
            }
        }
    }
    
    public func flush() {
        flushEvents()
    }

    struct FlushReponse: Decodable {
        struct Data: Decodable {
            var trackEvents: String
        }
        
        var data: Data
    }
    
    func flushEvents(minBatchSize: Int = 1) {
        // swiftlint:disable:next closure_body_length // TODO consider refactoring.
        serialQueue.addOperation {
            if self.uploadTask != nil {
                os_log("Skipping flush – already in progress", log: .events, type: .debug)
                return
            }
            
            if self.eventQueue.count < 1 {
                os_log("Skipping flush – no events in the queue", log: .events, type: .debug)
                return
            }
            
            if self.eventQueue.count < minBatchSize {
                os_log("Skipping flush – less than %d events in the queue", log: .events, type: .debug, minBatchSize)
                return
            }
            
            let events = Array(self.eventQueue.prefix(self.maxBatchSize))
            os_log("Uploading %d event(s) to server", log: .events, type: .debug, events.count)
            
            let uploadTask = self.client.task(with: events) { result in
                switch result {
                case let .error(error, isRetryable):
                    if let error = error {
                        os_log("Failed to upload events: %@", log: .events, type: .error, error.logDescription)
                    }
                    
                    if isRetryable {
                        os_log("Will retry failed events", log: .events, type: .info)
                    } else {
                        os_log("Discarding failed events", log: .events, type: .info)
                        self.removeEvents(events)
                    }
                case .success(let data):
                    do {
                        _ = try JSONDecoder.default.decode(FlushReponse.self, from: data)
                        os_log("Successfully uploaded %d event(s)", log: .events, type: .debug, events.count)
                        self.removeEvents(events)
                    } catch {
                        os_log("Failed to upload events: %@", log: .events, type: .error, error.logDescription)
                        os_log("Will retry failed events", log: .events, type: .info)
                    }
                }
                
                self.uploadTask = nil
                self.endBackgroundTask()
            }
            
            uploadTask.resume()
            self.uploadTask = uploadTask
        }
    }
    
    func removeEvents(_ eventsToRemove: [Event]) {
        serialQueue.addOperation {
            self.eventQueue = self.eventQueue.filter { event in
                !eventsToRemove.contains { $0.id == event.id }
            }
            
            os_log("Removed %d event(s) from queue – queue now contains %d event(s)", log: .events, type: .debug, eventsToRemove.count, self.eventQueue.count)
        }
        
        persistEvents()
    }
    
    public func addObserver(_ observer: EventQueueObserver) {
        let weakRef = WeakObserver(observer)
        observers.append(weakRef)
    }
}

// MARK: Timer

extension EventQueue {
    func startTimer() {
        self.stopTimer()
        
        guard self.flushInterval > 0.0 else {
            return
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: self.flushInterval, repeats: true) { [weak self] _ in
            self?.flushEvents()
        }
    }
    
    func stopTimer() {
        guard let timer = self.timer else {
            return
        }
        
        timer.invalidate()
        self.timer = nil
    }
}

// MARK: Background task

extension EventQueue {
    func beginBackgroundTask() {
        endBackgroundTask()
        
        serialQueue.addOperation {
            self.backgroundTask = UIApplication.shared.beginBackgroundTask {
                self.serialQueue.cancelAllOperations()
                self.endBackgroundTask()
            }
        }
    }
    
    func endBackgroundTask() {
        serialQueue.addOperation {
            if self.backgroundTask != UIBackgroundTaskIdentifier.invalid {
                let taskIdentifier = UIBackgroundTaskIdentifier(rawValue: self.backgroundTask.rawValue)
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                self.backgroundTask = UIBackgroundTaskIdentifier.invalid
            }
        }
    }
}

// MARK: Screen Tracking

public extension EventQueue {
    func trackScreenViewed(screenName: String, contentID: String? = nil, contentName: String? = nil) {
        self.addEvent(
            EventInfo(screenViewedWithName: screenName, contentID: contentID, contentName: contentName)
        )
    }
}

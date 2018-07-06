//
//  EventQueueService.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-09-01.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class EventQueueService: EventQueue {
    let client: GraphQLClient
    let flushAt: Int
    let flushInterval: Double
    let logger: Logger
    let maxBatchSize: Int
    let maxQueueSize: Int
    
    let serialQueue: Foundation.OperationQueue = {
        let q = Foundation.OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    struct WeakObserver {
        private(set) public weak var value: EventQueueObserver?
        
        public init(_ value: EventQueueObserver) {
            self.value = value
        }
    }
    
    var contextProviders = [ContextProvider]()
    var observers = [WeakObserver]()
    
    // The following variables comprise the state of the EventQueueService and should only be modified from within an operation on the serial queue
    
    var context = Context()
    var eventQueue = [Event]()
    var uploadTask: URLSessionTask?
    var timer: Timer?
    var backgroundTask = UIBackgroundTaskInvalid
    
    var cache: URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("events").appendingPathExtension("plist")
    }
    
    init(client: GraphQLClient, flushAt: Int, flushInterval: Double, logger: Logger, maxBatchSize: Int, maxQueueSize: Int) {
        self.client = client
        self.flushAt = flushAt
        self.flushInterval = flushInterval
        self.logger = logger
        self.maxBatchSize = maxBatchSize
        self.maxQueueSize = maxQueueSize
    }
    
    func addContextProviders(_ contextProviders: [ContextProvider]) {
        self.contextProviders = self.contextProviders + contextProviders
    }
    
    func restore() {
        restoreEvents()
        
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
            self.startTimer()
        }
        
        if (UIApplication.shared.applicationState == .active) {
            startTimer()
        }
        
        NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: nil) { _ in
            self.stopTimer()
        }
        
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { _ in
            self.beginBackgroundTask()
            self.flushEvents()
        }
    }
    
    func restoreEvents() {
        serialQueue.addOperation {
            self.logger.debug("Restoring events from cache...")
            
            guard let cache = self.cache else {
                self.logger.error("Cache not found")
                return
            }
            
            if !FileManager.default.fileExists(atPath: cache.path) {
                self.logger.debug("Cache is empty, no events to restore")
                return
            }
            
            do {
                let data = try Data(contentsOf: cache)
                self.eventQueue = try PropertyListDecoder().decode([Event].self, from: data)
                self.logger.debug("\(self.eventQueue.count) event(s) restored from cache")
            } catch {
                self.logger.error("Failed to restore events from cache")
                self.logger.error(error.localizedDescription)
            }
        }
    }
    
    func addEvent(_ info: EventInfo) {
        captureContext()
        
        serialQueue.addOperation {
            if self.eventQueue.count == self.maxQueueSize {
                self.logger.debug("Event queue is at capacity (\(self.maxQueueSize)) – removing oldest event")
                self.eventQueue.remove(at: 0)
            }
            
            let event = Event(name: info.name, context: self.context, namespace: info.namespace, attributes: info.attributes, timestamp: info.timestamp ?? Date())
            self.eventQueue.append(event)
            self.logger.debug("Added \"\(event.name)\" event to queue – queue now contains \(self.eventQueue.count) event(s)")
        }
        
        persistEvents()
        flushEvents(minBatchSize: flushAt)
        
        observers.compactMap({ $0.value }).forEach { $0.eventQueue(self, didAddEvent: info) }
    }
    
    func captureContext() {
        serialQueue.addOperation {
            self.logger.debug("Capturing context...")
            self.context = self.contextProviders.reduce(Context(), { $1.captureContext($0) })
            self.logger.debug("\(self.context)")
        }
    }
    
    func persistEvents() {
        serialQueue.addOperation {
            self.logger.debug("Persisting events to cache...")
            
            guard let cache = self.cache else {
                self.logger.error("Cache not found")
                return
            }
            
            do {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .xml
                let data = try encoder.encode(self.eventQueue)
                try data.write(to: cache, options: [.atomic])
                self.logger.debug("Cache now contains \(self.eventQueue.count) event(s)")
            } catch {
                self.logger.error("Failed to persist events to cache")
                self.logger.error(error.localizedDescription)
            }
        }
    }
    
    func flush() {
        flushEvents()
    }

    struct FlushReponse: Decodable {
        struct Data: Decodable {
            var trackEvents: String
        }
        
        var data: Data
    }
    
    func flushEvents(minBatchSize: Int = 1) {
        serialQueue.addOperation {
            if self.uploadTask != nil {
                self.logger.debug("Skipping flush – already in progress")
                return
            }
            
            if self.eventQueue.count < 1 {
                self.logger.debug("Skipping flush – no events in the queue")
                return
            }
            
            if self.eventQueue.count < minBatchSize {
                self.logger.debug("Skipping flush – less than \(minBatchSize) events in the queue")
                return
            }
            
            let events = Array(self.eventQueue.prefix(self.maxBatchSize))
            self.logger.debug("Uploading \(events.count) event(s) to server")
            
            let operation = TrackEventsMutation(events: events)
            let uploadTask = self.client.task(with: operation) { result in
                switch result {
                case .error(let error, let isRetryable):
                    if let error = error {
                        self.logger.error(error.localizedDescription)
                    }
                    
                    if isRetryable {
                        self.logger.error("Failed to upload events - will retry")
                    } else {
                        self.logger.error("Failed to upload events - discarding events")
                        self.removeEvents(events)
                    }
                case .success(let data):
                    do {
                        _ = try JSONDecoder().decode(FlushReponse.self, from: data)
                        self.logger.debug("Successfully uploaded \(events.count) event(s)")
                        self.removeEvents(events)
                    } catch {
                        self.logger.error("Failed to upload events - will retry")
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
                !eventsToRemove.contains() { $0.id == event.id }
            }
            self.logger.debug("Removed \(eventsToRemove.count) event(s) from queue – queue now contains \(self.eventQueue.count) event(s)")
        }
        
        persistEvents()
    }
    
    func addObserver(_ observer: EventQueueObserver) {
        let weakRef = WeakObserver(observer)
        observers.append(weakRef)
    }
}

// MARK: Timer

extension EventQueueService {
    func startTimer() {
        stopTimer()
        
        serialQueue.addOperation {
            guard self.flushInterval > 0.0 else {
                return
            }
            
            let timer = Timer(timeInterval: self.flushInterval, repeats: true) { _ in
                self.flushEvents()
            }
            
            DispatchQueue.main.async {
                RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
            }
            
            self.timer = timer
        }
    }
    
    func stopTimer() {
        serialQueue.addOperation {
            guard let timer = self.timer else {
                return
            }
            
            DispatchQueue.main.async {
                timer.invalidate()
            }
            
            self.timer = nil
        }
    }
}

// MARK: Background task

extension EventQueueService {
    func beginBackgroundTask() {
        endBackgroundTask()
        
        serialQueue.addOperation {
            self.backgroundTask = UIApplication.shared.beginBackgroundTask() {
                self.serialQueue.cancelAllOperations()
                self.endBackgroundTask()
            }
        }
    }
    
    func endBackgroundTask() {
        serialQueue.addOperation {
            if (self.backgroundTask != UIBackgroundTaskInvalid) {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = UIBackgroundTaskInvalid
            }
        }
    }
}

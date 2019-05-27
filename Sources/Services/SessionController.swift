//
//  SessionController.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

/// Responsible for emitting events including a view duration for open and closable registered sessions, such as
/// Experience Viewed or Screen Viewed.  Includes some basic hysteresis for ensuring that rapidly re-opened sessions are
/// aggregated into a single session.
class SessionController {
    /// The shared singleton sesion controller.
    static let shared = SessionController()
    
    private let keepAliveTime: Int = 10
    private var observers: [NSObjectProtocol] = []
    
    private init() {
        #if swift(>=4.2)
        let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
        let willResignActiveNotification = UIApplication.willResignActiveNotification
        #else
        let didBecomeActiveNotification = NSNotification.Name.UIApplicationDidBecomeActive
        let willResignActiveNotification = NSNotification.Name.UIApplicationWillResignActive
        #endif
        
        observers = [
            NotificationCenter.default.addObserver(
                forName: didBecomeActiveNotification,
                object: nil,
                queue: OperationQueue.main,
                using: { _ in
                    self.entries.forEach {
                        $0.value.session.start()
                    }
                }
            ),
            NotificationCenter.default.addObserver(
                forName: willResignActiveNotification,
                object: nil,
                queue: OperationQueue.main,
                using: { _ in
                    self.entries.forEach {
                        $0.value.session.end()
                    }
                }
            )
        ]
    }
    
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
    
    // MARK: Registration
    
    private struct Entry {
        let session: Session
        var isUnregistered = false
        
        init(session: Session) {
            self.session = session
        }
    }
    
    private var entries = [String: Entry]()
    
    func registerSession(identifier: String, completionHandler: @escaping (Double) -> Void) {
        if var entry = entries[identifier] {
            entry.session.start()
            
            if entry.isUnregistered {
                entry.isUnregistered = false
                entries[identifier] = entry
            }
            
            return
        }
        
        let session = Session(keepAliveTime: keepAliveTime) { result in
            completionHandler(result.duration)
            
            if let entry = self.entries[identifier], entry.isUnregistered {
                self.entries[identifier] = nil
            }
        }
        
        session.start()
        entries[identifier] = Entry(session: session)
    }
    
    func unregisterSession(identifier: String) {
        if var entry = entries[identifier] {
            entry.isUnregistered = true
            entries[identifier] = entry
            entry.session.end()
        }
    }
}

fileprivate class Session {
    let keepAliveTime: Int
    
    struct Result {
        var startedAt: Date
        var endedAt: Date
        
        var duration: Double {
            return endedAt.timeIntervalSince1970 - startedAt.timeIntervalSince1970
        }
        
        init(startedAt: Date, endedAt: Date) {
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
        
        init(startedAt: Date) {
            let now = Date()
            self.init(startedAt: startedAt, endedAt: now)
        }
    }
    
    private let completionHandler: (Result) -> Void
    
    enum State {
        case ready
        case started(startedAt: Date)
        case ending(startedAt: Date, timer: Timer)
        case complete(result: Result)
    }
    
    private(set) var state: State = .ready {
        didSet {
            if case .complete(let result) = state {
                completionHandler(result)
            }
        }
    }
    
    init(keepAliveTime: Int, completionHandler: @escaping (Result) -> Void) {
        self.keepAliveTime = keepAliveTime
        self.completionHandler = completionHandler
    }
    
    func start() {
        switch state {
        case .ready, .complete:
            let now = Date()
            state = .started(startedAt: now)
        case .started:
            break
        case let .ending(startedAt, timer):
            timer.invalidate()
            state = .started(startedAt: startedAt)
        }
    }
    
    func end() {
        switch state {
        case .ready, .ending, .complete:
            break
        case .started(let startedAt):
            // Capture endedAt now, as opposed to when the timer fires
            let endedAt = Date()
            
            // Start a background task before running the timer to allow it to run its course if the app is backgrounded while ending the session.
            var backgroundTaskID: UIBackgroundTaskIdentifier!
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Keep Alive Timer") { [weak self] in
                self?.finish(endedAt: endedAt)
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            
            let timeInterval = TimeInterval(keepAliveTime)
            let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] _ in
                self?.finish(endedAt: endedAt)
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            })
            
            state = .ending(startedAt: startedAt, timer: timer)
        }
    }
    
    func finish(endedAt: Date) {
        switch state {
        case let .ending(startedAt, timer):
            timer.invalidate()
            let result = Result(startedAt: startedAt, endedAt: endedAt)
            state = .complete(result: result)
        default:
            break
        }
    }
}

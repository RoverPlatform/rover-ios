//
//  SessionControllerService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class SessionControllerService: SessionController {
    let eventQueue: EventQueue
    let keepAliveTime: Int
    
    struct SessionEntry {
        let session: Session
        
        var isUnregistered = false
        
        init(session: Session) {
            self.session = session
        }
    }
    
    var sessions = [String: SessionEntry]()
    
    var didBecomeActiveObserver: NSObjectProtocol?
    var willResignActiveObserver: NSObjectProtocol?
    
    init(eventQueue: EventQueue, keepAliveTime: Int) {
        self.eventQueue = eventQueue
        self.keepAliveTime = keepAliveTime
        
        #if swift(>=4.2)
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.sessions.forEach {
                $0.value.session.start()
            }
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.sessions.forEach {
                $0.value.session.end()
            }
        }
        #else
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.sessions.forEach {
                $0.value.session.start()
            }
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.sessions.forEach {
                $0.value.session.end()
            }
        }
        #endif
    }
    
    deinit {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = willResignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func registerSession(identifier: String, completionHandler: @escaping (Double) -> EventInfo) {
        if var entry = sessions[identifier] {
            entry.session.start()
            
            if entry.isUnregistered {
                entry.isUnregistered = false
                sessions[identifier] = entry
            }
            
            return
        }
        
        let session = Session(keepAliveTime: keepAliveTime) { [weak self] result in
            let event = completionHandler(result.duration)
            self?.eventQueue.addEvent(event)
            
            if let entry = self?.sessions[identifier], entry.isUnregistered {
                self?.sessions[identifier] = nil
            }
        }
        
        session.start()
        sessions[identifier] = SessionEntry(session: session)
    }
    
    func unregisterSession(identifier: String) {
        if var entry = sessions[identifier] {
            entry.isUnregistered = true
            sessions[identifier] = entry
            entry.session.end()
        }
    }
}

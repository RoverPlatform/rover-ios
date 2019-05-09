//
//  SessionController.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

/// Responsible for emitting events including a view duration for open and closable registered sessions, such as Experience Viewed or Screen Viewed.  Includes some basic hysteresis for ensuring that rapidly re-opened sessions are aggregated into a single session.
public class SessionController {
    let keepAliveTime: Int
    let observers: [NSObjectProtocol]
    
    public init(keepAliveTime: Int) {
        self.keepAliveTime = keepAliveTime
        
        observers = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: OperationQueue.main,
                using: { _ in
                    SessionState.shared.forEach {
                        $0.value.session.start()
                    }
                }
            ),
            NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: OperationQueue.main,
                using: { _ in
                    SessionState.shared.forEach {
                        $0.value.session.end()
                    }
                }
            )
        ]
    }
    
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
    
    public func registerSession(identifier: String, completionHandler: @escaping (Double) -> Void) {
        if var entry = SessionState.shared[identifier] {
            entry.session.start()
            
            if entry.isUnregistered {
                entry.isUnregistered = false
                SessionState.shared[identifier] = entry
            }
            
            return
        }
        
        let session = Session(keepAliveTime: keepAliveTime) { result in
            completionHandler(result.duration)
            
            if let entry = SessionState.shared[identifier], entry.isUnregistered {
                SessionState.shared[identifier] = nil
            }
        }
        
        session.start()
        SessionState.shared[identifier] = SessionState.Entry(session: session)
    }
    
    public func unregisterSession(identifier: String) {
        if var entry = SessionState.shared[identifier] {
            entry.isUnregistered = true
            SessionState.shared[identifier] = entry
            entry.session.end()
        }
    }
}

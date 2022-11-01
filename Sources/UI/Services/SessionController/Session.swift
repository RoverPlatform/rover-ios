//
//  Session.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class Session {
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
            let timeInterval = TimeInterval(keepAliveTime)
            let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self, startedAt, endedAt] _ in
                guard let session = self else {
                    return
                }
                
                let result = Result(startedAt: startedAt, endedAt: endedAt)
                session.state = .complete(result: result)
            })
            
            state = .ending(startedAt: startedAt, timer: timer)
        }
    }
    
    func finish() {
        end()
    }
}

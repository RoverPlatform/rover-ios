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
import RoverFoundation
import RoverData

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

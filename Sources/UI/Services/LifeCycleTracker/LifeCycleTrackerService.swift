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

class LifeCycleTrackerService: LifeCycleTracker {
    let eventQueue: EventQueue
    let sessionController: SessionController
    
    var didBecomeActiveObserver: NSObjectProtocol?
    var willResignActiveObserver: NSObjectProtocol?
    
    init(eventQueue: EventQueue, sessionController: SessionController) {
        self.eventQueue = eventQueue
        self.sessionController = sessionController
    }
    
    func enable() {
        self.sessionController.registerSession(identifier: "application") { duration in
            let attributes: Attributes = ["duration": duration]
            return EventInfo(name: "App Viewed", namespace: "rover", attributes: attributes)
        }
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Opened", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Closed", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
    }
    
    func disable() {
        self.sessionController.unregisterSession(identifier: "application")
    
        if let didBecomeActiveObserver = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }
        
        if let willResignActiveObserver = willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
            self.willResignActiveObserver = nil
        }
    }
    
    deinit {
        self.disable()
    }
}

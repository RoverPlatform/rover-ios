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

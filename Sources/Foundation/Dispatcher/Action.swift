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

open class Action: Operation {
    override open var isAsynchronous: Bool {
        return true
    }
    
    private var _isExecuting = false {
        willSet {
            willChangeValue(for: \.isExecuting)
        }
        didSet {
            didChangeValue(for: \.isExecuting)
        }
    }
    
    override open var isExecuting: Bool {
        return _isExecuting
    }
    
    private var _isFinished = false {
        willSet {
            willChangeValue(for: \.isFinished)
        }
        
        didSet {
            didChangeValue(for: \.isFinished)
        }
    }
    
    override open var isFinished: Bool {
        return _isFinished
    }
    
    // MARK: Execution
    
    override open func start() {
        super.start()
        
        if isCancelled {
            finish()
        }
    }
    
    override open func main() {
        if isCancelled {
            finish()
            return
        }
        
        _isExecuting = true
        
        for observer in observers {
            observer.actionDidStart(self)
        }
        
        execute()
    }
    
    open func execute() {
        finish()
    }
    
    public final func produceAction(_ action: Action) {
        for observer in observers {
            observer.action(self, didProduceAction: action)
        }
    }
    
    // MARK: Finishing
    
    public final func finish(error: Error?) {
        if let error = error {
            finish(errors: [error])
        } else {
            finish()
        }
    }
    
    public final func finish(errors: [Error] = []) {
        for observer in observers {
            observer.actionDidFinish(self, errors: errors)
        }
        
        _isExecuting = false
        _isFinished = true
    }
    
    // MARK: Observers
    
    public private(set) var observers = [ActionObserver]()
    
    public func addObserver(observer: ActionObserver) {
        guard !isExecuting else {
            return
        }
        
        observers.append(observer)
    }
}

//
//  Action.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

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

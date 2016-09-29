//
//  ConcurrentOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-15.
//
//

import UIKit

open class ConcurrentOperation: Operation {
    fileprivate var _finished = false
    fileprivate var _executing = false
    override fileprivate(set) open var isFinished: Bool {
        get { return _finished }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    override fileprivate(set) open var isExecuting: Bool {
        get { return _executing }
        set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    override final public var isConcurrent: Bool {
        return true
    }
    
    override open var isAsynchronous: Bool {
        return true
    }
    
    
    override final public func start() {
        guard !isCancelled else {
            finish()
            return
        }
        
        isExecuting = true
        
        execute()
    }
    
    func execute() {
        print("\(type(of: self)) must override `execute()`.")
        
        finish()
    }
    
    final func finish() {
        if isExecuting {
            isExecuting = false
        }
        isFinished = true
    }
}

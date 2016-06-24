//
//  ConcurrentOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-15.
//
//

import UIKit

public class ConcurrentOperation: NSOperation {
    private var _finished = false
    private var _executing = false
    override private(set) public var finished: Bool {
        get { return _finished }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    override private(set) public var executing: Bool {
        get { return _executing }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    override final public var concurrent: Bool {
        return true
    }
    
    override public var asynchronous: Bool {
        return true
    }
    
    
    override final public func start() {
        guard !cancelled else {
            finish()
            return
        }
        
        executing = true
        
        execute()
    }
    
    func execute() {
        print("\(self.dynamicType) must override `execute()`.")
        
        finish()
    }
    
    final func finish() {
        if executing {
            executing = false
        }
        finished = true
    }
}

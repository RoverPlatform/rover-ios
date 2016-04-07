//
//  ConcurrentOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-15.
//
//

import UIKit

class ConcurrentOperation: NSOperation {
    private var _finished = false
    private var _executing = false
    override private(set) var finished: Bool {
        get { return _finished }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    override private(set) var executing: Bool {
        get { return _executing }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    override final var concurrent: Bool {
        return true
    }
    
    
    override final func start() {
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

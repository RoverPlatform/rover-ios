//
//  ObserverSet.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

/*
 Inspired by:
 http://blog.scottlogic.com/2015/02/11/swift-kvo-alternatives.html
 https://mikeash.com/pyblog/friday-qa-2015-01-23-lets-build-swift-notifications.html
 https://developer.apple.com/videos/play/wwdc2017/212/?time=1182
 */
public struct ObserverSet<Parameters> {
    private struct Observer {
        weak var token: NSObjectProtocol?
        let block: (Parameters) -> Void
    }
    
    private var observers = [Observer]()
    
    public init() { }
    
    public mutating func add(block: @escaping (Parameters) -> Void) -> NSObjectProtocol {
        let token = NSObject()
        let observer = Observer(token: token, block: block)
        observers.append(observer)
        return token
    }
    
    public mutating func remove(token: NSObjectProtocol) {
        observers = observers.filter { $0.token !== token }
    }
    
    public mutating func notify(parameters: Parameters) {
        let observers = self.observers.filter { $0.token != nil }
        observers.forEach { $0.block(parameters) }
        self.observers = observers
    }
}

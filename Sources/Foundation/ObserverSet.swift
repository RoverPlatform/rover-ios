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

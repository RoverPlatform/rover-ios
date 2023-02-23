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

public struct BlockObserver: ActionObserver {
    public typealias StartHandler = (Action) -> Void
    public typealias ProduceHandler = (Action, Action) -> Void
    public typealias FinishHandler = (Action, [Error]) -> Void
    
    private let startHandler: StartHandler?
    private let produceHandler: ProduceHandler?
    private let finishHandler: FinishHandler?
    
    public init(startHandler: StartHandler? = nil, produceHandler: ProduceHandler? = nil, finishHandler: FinishHandler? = nil) {
        self.startHandler = startHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }
    
    public func actionDidStart(_ action: Action) {
        startHandler?(action)
    }
    
    public func action(_ action: Action, didProduceAction newAction: Action) {
        produceHandler?(action, newAction)
    }
    
    public func actionDidFinish(_ action: Action, errors: [Error]) {
        finishHandler?(action, errors)
    }
}

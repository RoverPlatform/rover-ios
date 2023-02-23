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
import os.log

class DispatcherService: OperationQueue, Dispatcher {
    func dispatch(_ action: Action, completionHandler: (() -> Void)?) {
        let produceHandler: BlockObserver.ProduceHandler = { [weak self] in
            self?.addOperation($1)
        }
        
        let finishHandler: BlockObserver.FinishHandler = { _, _  in
            completionHandler?()
        }
        
        let observer = BlockObserver(produceHandler: produceHandler, finishHandler: finishHandler)
        action.addObserver(observer: observer)
        
        super.addOperation(action)
    }
}

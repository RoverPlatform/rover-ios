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


public class Rover {
    var services = [ServiceKey: Any]()
    
    public static var shared: Rover {
        guard let sharedInstance = sharedInstance else {
            fatalError("Rover must be initialized before use.")
        }
        
        return sharedInstance
    }
    
    private init(assemblers: [Assembler]) {
        assemblers.forEach { $0.assemble(container: self) }
        assemblers.forEach { $0.containerDidAssemble(resolver: self) }
        
        if !Thread.isMainThread {
            os_log("Rover must be initialized on the main thread", log: .general, type: .default)
        }
    }
    
    private static var sharedInstance: Rover? = nil
    
    public static func initialize(assemblers: [Assembler]) {
        guard sharedInstance == nil else {
            os_log("Rover already initialized", log: .general, type: .default)
            return
        }
        
        sharedInstance = Rover(assemblers: assemblers)
    }

    public static func deinitialize() {
        sharedInstance = nil
    }

}

// MARK: Container

extension Rover: Container {
    public func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey) {
        services[key] = entry
    }
}

// MARK: Resolver

extension Rover: Resolver {
    public func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>? {
        return services[key] as? ServiceEntry<Service>
    }
}

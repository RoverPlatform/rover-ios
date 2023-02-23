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

import UIKit
import RoverFoundation
import RoverUI
import RoverData

public struct DebugAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        // MARK: Action (settings)
        
        container.register(Action.self, name: "settings", scope: .transient) { resolver in
            PresentViewAction(
                viewControllerToPresent: resolver.resolve(UIViewController.self, name: "settings")!,
                animated: true
            )
        }
        
        // MARK: DebugContextProvider
        
        container.register(DebugContextProvider.self) { _ in
            DebugContextManager()
        }
        
        // MARK: RouteHandler (settings)
        
        container.register(RouteHandler.self, name: "settings") { resolver in
            let actionProvider: SettingsRouteHandler.ActionProvider = { [weak resolver] in
                resolver?.resolve(Action.self, name: "settings")
            }
            
            return SettingsRouteHandler(actionProvider: actionProvider)
        }
        
        // MARK: UIViewController (settings)
        
        container.register(UIViewController.self, name: "settings", scope: .transient) { _ in
            RoverSettingsViewController()
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let handler = resolver.resolve(RouteHandler.self, name: "settings")!
        resolver.resolve(Router.self)!.addHandler(handler)
    }
}

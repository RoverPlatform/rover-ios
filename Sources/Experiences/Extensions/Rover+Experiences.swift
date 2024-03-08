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

import RoverFoundation
import Foundation

extension Rover {
    
    /// Register a callback that the Rover SDK will call when the user taps on a layer with an action type of "custom". Use this to implement the behavior for custom buttons and the like.
    ///
    /// The callback is given a ``CustomActionActivationEvent`` value.
    
    public func registerCustomActionCallback(_ callback: @escaping (CustomActionActivationEvent) -> Void) {
        Rover.shared.resolve(ExperienceManager.self)?.registeredCustomActionCallback = callback
    }
    
    /// Register a callback that the Rover SDK will call when the user views a screen.  Use this to integrate with other analytics solutions.
    ///
    /// The callback is given a ``ScreenViewedEvent`` value.
    
    public func registerScreenViewedCallback(_ callback: @escaping (ScreenViewedEvent) -> Void) {
        Rover.shared.resolve(ExperienceManager.self)?.registeredScreenViewedCallback = callback
    }
    
    /// Register a callback that the Rover SDK will call when the user taps a button.  Use this to integrate with other analytics solutions.
    ///
    /// The callback is given a ``ScreenViewedEvent`` value.
    public func registerButtonTappedCallback(_ callback: @escaping (ButtonTappedEvent) -> Void) {
        Rover.shared.resolve(ExperienceManager.self)?.registeredButtonTappedCallback = callback
    }
    
    /// Supply the domain name this authorizer matches against including subdomain. You can optionally supply an asterisk for the subdomain if you want to match against all subdomains.
    
    public func authorize(pattern: String, block: @escaping (inout URLRequest) -> Void) {
        Rover.shared.resolve(ExperienceManager.self)?.authorize(pattern, with: block)
    }
}

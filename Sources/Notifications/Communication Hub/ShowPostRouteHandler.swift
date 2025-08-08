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
import RoverFoundation
import RoverUI

class ShowPostRouteHandler: RouteHandler {
    typealias PostsListActionProvider = (String?) -> Action?

    let postsListActionProvider: PostsListActionProvider
    
    init(
        postsListActionProvider: @escaping PostsListActionProvider
    ) {
        self.postsListActionProvider = postsListActionProvider
    }
    
    func deepLinkAction(url: URL, domain: String?) -> Action? {
        os_log("Processing deep link: %@", log: .communicationHub, type: .debug, url.absoluteString)
        
        guard let host = url.host else {
            os_log("Invalid deep link URL - missing host: %@", log: .communicationHub, type: .default, url.absoluteString)
            return nil
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch host {
            
        case "posts":
            if pathComponents.count == 1 {
                // rv-myapp://posts/:id
                let postId = pathComponents[0]
                os_log("Routing to standalone posts with post ID: %@", log: .communicationHub, type: .debug, postId)
                return postsListActionProvider(postId)
            } else {
                os_log("Invalid deep link: %@", log: .communicationHub, type: .default, host)
                return nil
            }

        default:
            os_log("Unrecognized deep link host: %@", log: .communicationHub, type: .default, host)
            return nil
        }
        
        os_log("No matching route found for deep link: %@", log: .communicationHub, type: .default, url.absoluteString)
        return nil
    }
}

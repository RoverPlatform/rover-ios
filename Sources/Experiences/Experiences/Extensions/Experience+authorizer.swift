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

extension ExperienceModel {
    /// Convert the document-level authorizers, intended for design-time use, into live authorizers that can be used by the SDK.
    func getAuthorizers() -> Authorizers {
        var authorizers = Authorizers()
        
        for documentAuthorizer in self.authorizers {
            authorizers.authorize(documentAuthorizer.pattern) { request in
                guard let url = request.url, let host = request.url?.host else {
                    return
                }
                
                switch documentAuthorizer.method {
                case .header:
                    request.setValue(documentAuthorizer.value, forHTTPHeaderField: documentAuthorizer.key)
                case .queryString:
                    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                        return
                    }
                    
                    var queryItems = components.queryItems ?? []
                    
                    let queryItem = URLQueryItem(name: documentAuthorizer.key, value: documentAuthorizer.value)
                    queryItems.append(queryItem)
                    components.queryItems = queryItems
                    request.url = components.url
                }
            }
        }
        
        return authorizers
    }
}

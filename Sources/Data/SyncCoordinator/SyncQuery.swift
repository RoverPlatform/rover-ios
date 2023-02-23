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

public struct SyncQuery {
    public struct Argument: Equatable, Hashable {
        public var name: String
        public var type: String
        
        public init(name: String, type: String) {
            self.name = name
            self.type = type
        }
    }
    
    public var name: String
    public var body: String
    public var arguments: [Argument]
    public var fragments: [String]
    
    public init(name: String, body: String, arguments: [Argument], fragments: [String]) {
        self.name = name
        self.body = body
        self.arguments = arguments
        self.fragments = fragments
    }
}

extension SyncQuery {
    var signature: String? {
        if arguments.isEmpty {
            return nil
        }
        
        return arguments.map {
            "$\(name)\($0.name.capitalized):\($0.type)"
        }.joined(separator: ", ")
    }
    
    var definition: String {
        let expression: String = {
            if arguments.isEmpty {
                return ""
            }
            
            let signature = arguments.map {
                "\($0.name):$\(name)\($0.name.capitalized)"
            }.joined(separator: ", ")
            
            return "(\(signature))"
        }()
        
        return """
            \(name)\(expression) {
                \(body)
            }
            """
    }
}

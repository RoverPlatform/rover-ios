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

public struct ClassicImage: Decodable {
    public var height: Int
    public var isURLOptimizationEnabled: Bool
    public var name: String
    public var size: Int
    public var width: Int
    public var url: URL
    public var accessibilityLabel: String?
    public var isDecorative: Bool
    
    public init(height: Int, isURLOptimizationEnabled: Bool, name: String, size: Int, width: Int, url: URL, accessibilityLabel: String?, isDecorative: Bool) {
        self.height = height
        self.isURLOptimizationEnabled = isURLOptimizationEnabled
        self.name = name
        self.size = size
        self.width = width
        self.url = url
        self.accessibilityLabel = accessibilityLabel
        self.isDecorative = isDecorative
    }
}

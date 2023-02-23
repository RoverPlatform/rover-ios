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

public struct ClassicBackground: Decodable {
    public enum ContentMode: String, Decodable {
        case original = "ORIGINAL"
        case stretch = "STRETCH"
        case tile = "TILE"
        case fill = "FILL"
        case fit = "FIT"
    }
    
    public enum Scale: String, Decodable {
        case x1 = "X1"
        case x2 = "X2"
        case x3 = "X3"
    }
    
    public var color: ClassicColor
    public var contentMode: ContentMode
    public var image: ClassicImage?
    public var scale: Scale
    
    public init(color: ClassicColor, contentMode: ContentMode, image: ClassicImage?, scale: Scale) {
        self.color = color
        self.contentMode = contentMode
        self.image = image
        self.scale = scale
    }
}

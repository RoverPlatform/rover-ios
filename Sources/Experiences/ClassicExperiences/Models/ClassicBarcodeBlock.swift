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

public struct ClassicBarcodeBlock: ClassicBlock {
    public var background: ClassicBackground
    public var barcode: ClassicBarcode
    public var border: ClassicBorder
    public var id: String
    public var name: String
    public var insets: ClassicInsets
    public var opacity: Double
    public var position: ClassicPosition
    public var tapBehavior: ClassicBlockTapBehavior
    public var keys: [String: String]
    public var tags: [String]
    public var conversion: ClassicConversion?

    
    public init(background: ClassicBackground, barcode: ClassicBarcode, border: ClassicBorder, id: String, name: String, insets: ClassicInsets, opacity: Double, position: ClassicPosition, tapBehavior: ClassicBlockTapBehavior, keys: [String: String], tags: [String], conversion: ClassicConversion?) {
        self.background = background
        self.barcode = barcode
        self.border = border
        self.id = id
        self.name = name
        self.insets = insets
        self.opacity = opacity
        self.position = position
        self.tapBehavior = tapBehavior
        self.keys = keys
        self.tags = tags
        self.conversion = conversion
    }
}

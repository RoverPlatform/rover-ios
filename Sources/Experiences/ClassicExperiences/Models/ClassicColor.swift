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

public struct ClassicColor: Decodable {
    public var red: Int
    public var green: Int
    public var blue: Int
    public var alpha: Double
    
    public init(red: Int, green: Int, blue: Int, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: Convenience Initializers

extension ClassicColor {
    var uiColor: UIColor {
        let red = CGFloat(self.red) / 255.0
        let green = CGFloat(self.green) / 255.0
        let blue = CGFloat(self.blue) / 255.0
        let alpha = CGFloat(self.alpha)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func uiColor(dimmedBy: Double) -> UIColor {
        let red = CGFloat(self.red) / 255.0
        let green = CGFloat(self.green) / 255.0
        let blue = CGFloat(self.blue) / 255.0
        let alpha = CGFloat(self.alpha) * CGFloat(dimmedBy)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    static var white: ClassicColor { return ClassicColor(red: 255, green: 255, blue: 255, alpha: 1) }
    static var transparent: ClassicColor { return ClassicColor(red: 0, green: 0, blue: 0, alpha: 0) }
}

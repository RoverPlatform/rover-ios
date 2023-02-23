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

extension UIView {
    func configureOpacity(opacity: Double?) {
        self.alpha = opacity.map { CGFloat($0) } ?? 0.0
    }
    
    func configureBorder(border: ClassicBorder?, constrainedByFrame frame: CGRect?) {
        guard let border = border else {
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
            layer.cornerRadius = 0
            return
        }
        
        layer.borderColor = border.color.uiColor.cgColor
        layer.borderWidth = CGFloat(border.width)
        layer.cornerRadius = {
            let radius = CGFloat(border.radius)
            guard let frame = frame else {
                return radius
            }
            let maxRadius = min(frame.height, frame.width) / 2
            return min(radius, maxRadius)
        }()
    }
    
    func configureBackgroundColor(color: ClassicColor?, opacity: Double?) {
        guard let color = color, let opacity = opacity else {
            backgroundColor = UIColor.clear
            return
        }
        
        self.backgroundColor = color.uiColor(dimmedBy: opacity)
    }
    
    func configureContent(content: UIView, withInsets insets: ClassicInsets) {
        NSLayoutConstraint.deactivate(self.constraints)
        self.removeConstraints(self.constraints)
        
        let insets: UIEdgeInsets = {
            let top = CGFloat(insets.top)
            let left = CGFloat(insets.left)
            let bottom = 0 - CGFloat(insets.bottom)
            let right = 0 - CGFloat(insets.right)
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }()
        
        content.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: insets.bottom).isActive = true
        content.leftAnchor.constraint(equalTo: self.leftAnchor, constant: insets.left).isActive = true
        content.rightAnchor.constraint(equalTo: self.rightAnchor, constant: insets.right).isActive = true
        content.topAnchor.constraint(equalTo: self.topAnchor, constant: insets.top).isActive = true
    }
}

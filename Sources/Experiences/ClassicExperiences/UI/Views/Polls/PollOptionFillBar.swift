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

class PollOptionFillBar: UIView {
    let fillView = UIView()
    var widthConstraint: NSLayoutConstraint!
    
    init(color: ClassicColor) {
        super.init(frame: .zero)
        clipsToBounds = true
        fillView.backgroundColor = color.uiColor
        fillView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fillView)
        NSLayoutConstraint.activate([
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.topAnchor.constraint(equalTo: topAnchor)
        ])
        
        widthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setFillPercentage(to fillPercentage: Double, animated: Bool) {
        assert(fillPercentage >= 0)
        assert(fillPercentage <= 1)
        
        widthConstraint.isActive = false
        widthConstraint = fillView.widthAnchor.constraint(
            equalTo: widthAnchor,
            multiplier: CGFloat(fillPercentage)
        )
        
        widthConstraint.isActive = true

        let duration = animated ? 1.0 : 0.0
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: {
            self.layoutIfNeeded()
            self.fillView.layoutIfNeeded()
        })
    }
}

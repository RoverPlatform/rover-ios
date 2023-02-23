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

class PollOptionPercentageLabel: UILabel {
    var animationTimer: Timer?
    var currentFraction = 0.0
    var widthConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        widthConstraint = widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setPercentage(to percentage: Int?, animated: Bool) {
        guard let percentage = percentage else {
            text = nil
            widthConstraint.constant = 0
            return
        }
        
        assert(percentage >= 0)
        assert(percentage <= 100)
        
        let textToMeasure: String
        switch percentage {
        case 100:
            textToMeasure = "100%"
        case let x where x < 10:
            textToMeasure = "8%"
        default:
            textToMeasure = "88%"
        }
        
        let fontAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font!]
        let size = (textToMeasure as NSString).size(withAttributes: fontAttributes)
        widthConstraint.constant = size.width + 1
        
        // Animate
        
        if let animationTimer = animationTimer {
            animationTimer.invalidate()
            self.animationTimer = nil
        }
    
        let startTime = Date()
        let startProportion = self.currentFraction
        let fraction = Double(percentage) / 100.0
        if animated && startProportion != fraction {
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] timer in
                let elapsed = Double(startTime.timeIntervalSinceNow) * -1
                let elapsedProportion = elapsed / 1.0
                if elapsedProportion > 1.0 {
                    self?.text = "\(percentage)%"
                    timer.invalidate()
                    self?.animationTimer = nil
                } else {
                    let percentage = (startProportion * 100).rounded(.down) + ((fraction - startProportion) * 100).rounded(.down) * elapsedProportion
                    self?.text = String(format: "%.0f%%", percentage)
                }
            })
        } else {
            self.text = "\(percentage)%"
        }

        self.currentFraction = fraction
    }
}

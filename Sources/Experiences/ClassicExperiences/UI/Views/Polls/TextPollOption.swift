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

import os.log
import UIKit

class TextPollOption: UIView {
    let backgroundView = UIImageView()
    let fillBar: PollOptionFillBar
    let textContainer: TextPollOptionTextContainer
    
    let option: ClassicTextPollBlock.TextPoll.Option
    let tapHandler: () -> Void
    
    init(option: ClassicTextPollBlock.TextPoll.Option, tapHandler: @escaping () -> Void) {
        self.option = option
        self.tapHandler = tapHandler
        fillBar = PollOptionFillBar(color: option.resultFillColor)
        textContainer = TextPollOptionTextContainer(option: option)
        super.init(frame: .zero)
        
        clipsToBounds = true
        
        let borderWidth = CGFloat(option.border.width)
        layoutMargins = UIEdgeInsets(top: borderWidth, left: borderWidth, bottom: borderWidth, right: borderWidth)
        
        // Accessibility
        
        isAccessibilityElement = true
        accessibilityLabel = option.text.rawValue
        accessibilityHint = "Selects the option"
        accessibilityTraits = [.button]
        
        // height
        
        let height = CGFloat(option.height) + layoutMargins.top + layoutMargins.bottom
        let constraint = heightAnchor.constraint(equalToConstant: height)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        
        // backgroundView
        
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // fillBar
        
        fillBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fillBar)
        NSLayoutConstraint.activate([
            fillBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            fillBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillBar.topAnchor.constraint(equalTo: topAnchor),
            fillBar.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // textContainer
        
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textContainer)
        NSLayoutConstraint.activate([
            textContainer.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            textContainer.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            textContainer.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            textContainer.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
        
        // gestureRecognizer
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(gestureRecognizer)
        
        // configuration
        
        configureOpacity(opacity: option.opacity)
        configureBackgroundColor(color: option.background.color, opacity: option.opacity)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setResult(_ result: PollCell.OptionResult, animated: Bool) {
        fillBar.setFillPercentage(to: result.fraction, animated: animated)
        textContainer.setPercentage(to: result.percentage, animated: animated)
        textContainer.isSelected = result.selected
        
        // Accessibility
        
        accessibilityHint = nil
        accessibilityTraits.insert(.notEnabled)
        
        if result.selected {
            accessibilityTraits.insert(.selected)
        } else {
            accessibilityTraits.remove(.selected)
        }
        
        accessibilityValue = "\(result.percentage)%"
    }
    
    func clearResult() {
        fillBar.setFillPercentage(to: 0, animated: false)
        textContainer.setPercentage(to: nil, animated: false)
        textContainer.isSelected = false
        
        // Accessibility
        
        accessibilityHint = "Selects the option"
        accessibilityTraits.remove(.notEnabled)
        accessibilityTraits.remove(.selected)
    }
    
    @objc
    private func didTap(gestureRecognizer: UIGestureRecognizer) {
        tapHandler()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(border: option.border, constrainedByFrame: self.frame)
        // we defer configuring background image to here so that the layout has been calculated, and thus frame is available.
        backgroundView.configureAsBackgroundImage(background: option.background)
    }
}

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

class ImagePollOptionCaption: UIView {
    let indicator = UILabel()
    let optionLabel = UILabel()
    let stackView = UIStackView()
    
    let option: ClassicImagePollBlock.ImagePoll.Option
    
    var isSelected = false {
        didSet {
            if isSelected {
                if !stackView.arrangedSubviews.contains(indicator) {
                    stackView.insertArrangedSubview(indicator, at: 1)
                }
            } else {
                indicator.removeFromSuperview()
            }
        }
    }
    
    init(option: ClassicImagePollBlock.ImagePoll.Option) {
        self.option = option
        super.init(frame: .zero)
        
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // stackView
        
        stackView.spacing = 8
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
        
        // optionLabel
        
        optionLabel.font = option.text.font.uiFont
        optionLabel.text = option.text.rawValue
        optionLabel.textColor = option.text.color.uiColor
        optionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        optionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(optionLabel)
        
        // indicator
        
        indicator.font = option.text.font.uiFont
        indicator.text = "•"
        indicator.textColor = option.text.color.uiColor
        indicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

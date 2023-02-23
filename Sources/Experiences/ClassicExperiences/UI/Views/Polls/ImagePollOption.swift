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

class ImagePollOption: UIView {
    let stackView = UIStackView()
    let image: ImagePollOptionImage
    let caption: ImagePollOptionCaption
    let overlay: ImagePollOptionOverlay
    
    let option: ClassicImagePollBlock.ImagePoll.Option
    let tapHandler: () -> Void
    
    init(option: ClassicImagePollBlock.ImagePoll.Option, tapHandler: @escaping () -> Void) {
        self.option = option
        self.tapHandler = tapHandler
        image = ImagePollOptionImage(option: option)
        caption = ImagePollOptionCaption(option: option)
        overlay = ImagePollOptionOverlay(option: option)
        super.init(frame: .zero)
        
        clipsToBounds = true
        
        let borderWidth = CGFloat(option.border.width)
        layoutMargins = UIEdgeInsets(top: borderWidth, left: borderWidth, bottom: borderWidth, right: borderWidth)
        
        // Accessibility
        
        isAccessibilityElement = true
        accessibilityLabel = option.text.rawValue
        accessibilityHint = "Selects the option"
        accessibilityTraits = [.image, .button]
        
        // stackView
        
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
        
        // image
        stackView.addArrangedSubview(image)
        
        // caption
        stackView.addArrangedSubview(caption)
        
        // overlay
        
        overlay.alpha = 0
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.bottomAnchor.constraint(equalTo: image.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: image.leadingAnchor),
            overlay.topAnchor.constraint(equalTo: image.topAnchor),
            overlay.trailingAnchor.constraint(equalTo: image.trailingAnchor)
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
        overlay.fillBar.setFillPercentage(to: result.fraction, animated: animated)
        overlay.label.setPercentage(to: result.percentage, animated: animated)
        caption.isSelected = result.selected
        
        let duration: TimeInterval = animated ? 0.167 : 0
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            self?.overlay.alpha = 1
        })
        
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
        caption.isSelected = false
        overlay.alpha = 0
        
        // Accessibility
        
        accessibilityHint = "Selects the option"
        accessibilityTraits.remove(.notEnabled)
        accessibilityTraits.remove(.selected)
    }
    
    // MARK: Actions
    
    @objc
    private func didTap(gestureRecognizer: UIGestureRecognizer) {
        tapHandler()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(border: option.border, constrainedByFrame: self.frame)
    }
}

//
//  TextPollOptionTextContainer.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class TextPollOptionTextContainer: UIStackView {
    let indicator = Indicator()
    let optionLabel = UILabel()
    let percentageLabel = PollOptionPercentageLabel()
    
    let option: TextPollBlock.TextPoll.Option
    
    init(option: TextPollBlock.TextPoll.Option) {
        self.option = option
        super.init(frame: .zero)
        
        spacing = 8
        layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        isLayoutMarginsRelativeArrangement = true
        
        // indicator
        indicator.font = option.text.font.uiFont
        indicator.textColor = option.text.color.uiColor
        indicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        // optionLabel
        
        optionLabel.font = option.text.font.uiFont
        optionLabel.text = option.text.rawValue
        optionLabel.textColor = option.text.color.uiColor
        optionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        optionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addArrangedSubview(optionLabel)
        
        // percentageLabel
        
        // The font weight for the percentageLabel should be two stops heavier and the size should be 5% bigger.
        
        let bumpedFontWeight: Text.Font.Weight
        switch option.text.font.weight {
        case .ultraLight:
            bumpedFontWeight = .light
        case .thin:
            bumpedFontWeight = .regular
        case .light:
            bumpedFontWeight = .medium
        case .regular:
            bumpedFontWeight = .semiBold
        case .medium:
            bumpedFontWeight = .bold
        case .semiBold:
            bumpedFontWeight = .heavy
        case .bold:
            bumpedFontWeight = .black
        case .heavy:
            bumpedFontWeight = .black
        case .black:
            bumpedFontWeight = .black
        }
        
        let bumpedFontSize = option.text.font.size * 1.05
        percentageLabel.font = Text.Font(size: bumpedFontSize, weight: bumpedFontWeight).uiFont
        percentageLabel.textAlignment = .right
        percentageLabel.textColor = option.text.color.uiColor
        percentageLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        percentageLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isSelected = false {
        didSet {
            if isSelected {
                if !arrangedSubviews.contains(indicator) {
                    insertArrangedSubview(indicator, at: 1)
                }
            } else {
                indicator.removeFromSuperview()
            }
        }
    }
    
    func setPercentage(to percentage: Int?, animated: Bool) {
        percentageLabel.setPercentage(to: percentage, animated: animated)
        
        if percentage == nil {
            percentageLabel.removeFromSuperview()
        } else if !arrangedSubviews.contains(percentageLabel) {
            addArrangedSubview(percentageLabel)
        }
    }
}

// MARK: Indicator

class Indicator: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        text = "•"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 8, height: size.height)
    }
}

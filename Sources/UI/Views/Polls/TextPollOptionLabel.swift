//
//  TextPollOptionLabel.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class TextPollOptionLabel: UIStackView {
    let indicator = Indicator()
    let optionLabel = UILabel()
    let percentageLabel = UILabel()
    let percentageLabelWidthConstraint: NSLayoutConstraint
    
    let option: TextPollBlock.TextPoll.Option
    
    init(option: TextPollBlock.TextPoll.Option) {
        self.option = option
        percentageLabelWidthConstraint = percentageLabel.widthAnchor.constraint(equalToConstant: 0)
        percentageLabelWidthConstraint.isActive = true
        super.init(frame: .zero)
        
        spacing = 8
        layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        isLayoutMarginsRelativeArrangement = true
        
        // indicator
        indicator.font = option.text.font.uiFont
        indicator.textColor = option.text.color.uiColor
        indicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // optionLabel
        
        optionLabel.font = option.text.font.uiFont
        optionLabel.text = option.text.rawValue
        optionLabel.textColor = option.text.color.uiColor
        addArrangedSubview(optionLabel)
        
        // percentageLabel
        
        percentageLabel.textAlignment = .right
        percentageLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        percentageLabel.font = option.text.font.bumpedForPercentageIndicator.uiFont
        percentageLabel.text = "99%"
        percentageLabel.textColor = option.text.color.uiColor
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
    
    var previousPercentageProportion = 0.0
    var animationTimer: Timer?
    
    func setPercentage(to percentage: Int?, animated: Bool) {
        guard let percentage = percentage else {
            percentageLabel.text = nil
            percentageLabelWidthConstraint.constant = 0
            percentageLabel.removeFromSuperview()
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
        
        let font = option.text.font.bumpedForPercentageIndicator
        let string = font.attributedText(forPlainText: textToMeasure, color: option.text.color)
        let bounds = CGSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)
        let rect = string?.boundingRect(with: bounds, options: [], context: nil)
        let width = rect?.width.rounded(.up) ?? 0
        percentageLabelWidthConstraint.constant = width + 1
        
        if !arrangedSubviews.contains(percentageLabel) {
            addArrangedSubview(percentageLabel)
        }
        
        // Animate
        
        if let animationTimer = animationTimer {
            animationTimer.invalidate()
            self.animationTimer = nil
        }
    
        let startTime = Date()
        let startProportion = self.previousPercentageProportion
        let fraction = Double(percentage) / 100.0
        if animated && startProportion != fraction {
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] timer in
                let elapsed = Double(startTime.timeIntervalSinceNow) * -1
                let elapsedProportion = elapsed / 1.0
                if elapsedProportion > 1.0 {
                    self?.percentageLabel.text = "\(percentage)%"
                    timer.invalidate()
                    self?.animationTimer = nil
                } else {
                    let percentage = (startProportion * 100).rounded(.down) + ((fraction - startProportion) * 100).rounded(.down) * elapsedProportion
                    self?.percentageLabel.text = String(format: "%.0f%%", percentage)
                }
            })
        } else {
            self.percentageLabel.text = "\(percentage)%"
        }

        self.previousPercentageProportion = fraction
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

// MARK: Text Helpers

fileprivate extension Text.Font.Weight {
    /// Return a weight two stops heavier.
     var bumped: Text.Font.Weight {
        switch self {
        case .ultraLight:
            return .light
        case .thin:
            return .regular
        case .light:
            return .medium
        case .regular:
            return .semiBold
        case .medium:
            return .bold
        case .semiBold:
            return .heavy
        case .bold:
            return .black
        case .heavy:
            return .black
        case .black:
            return .black
        }
    }
}

fileprivate extension Text.Font {
     func attributedText(forPlainText text: String, color: Color) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: color, font: self)
        return text.attributedText(forFormat: .plain)
    }
    
    var bumpedForPercentageIndicator: Text.Font {
        return Text.Font(size: self.size * 1.05, weight: self.weight.bumped)
    }
}

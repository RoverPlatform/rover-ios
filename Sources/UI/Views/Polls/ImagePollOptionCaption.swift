//
//  ImagePollOptionCaption.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class ImagePollOptionCaption: UIView {
    let indicator = UILabel()
    let optionLabel = UILabel()
    let stackView = UIStackView()
    
    let option: ImagePollBlock.ImagePoll.Option
    
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
    
    init(option: ImagePollBlock.ImagePoll.Option) {
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
        stackView.addArrangedSubview(optionLabel)
        
        // indicator
        
        indicator.font = option.text.font.uiFont
        indicator.text = "•"
        indicator.textColor = option.text.color.uiColor
        indicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

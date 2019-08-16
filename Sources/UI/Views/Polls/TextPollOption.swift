//
//  TextPollOption.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class TextPollOption: UIView {
    let backgroundView = UIImageView()
    let fillBar: PollOptionFillBar
    let label: TextPollOptionLabel
    
    let option: TextPollBlock.TextPoll.Option
    let tapHandler: () -> Void
    
    init(option: TextPollBlock.TextPoll.Option, tapHandler: @escaping () -> Void) {
        self.option = option
        self.tapHandler = tapHandler
        fillBar = PollOptionFillBar(color: option.resultFillColor)
        label = TextPollOptionLabel(option: option)
        super.init(frame: .zero)
        
        clipsToBounds = true
        
        // height
        
        let height = CGFloat(option.height)
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
        
        // label
        
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)
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
        label.setPercentage(to: result.percentage, animated: animated)
        label.isSelected = result.selected
    }
    
    func clearResult() {
        fillBar.setFillPercentage(to: 0, animated: false)
        label.setPercentage(to: nil, animated: false)
        label.isSelected = false
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

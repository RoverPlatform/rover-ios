//
//  ImagePollOptionOverlay.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class ImagePollOptionOverlay: UIView {
    let fillBar: PollOptionFillBar
    let label = UILabel()
    let stackView = UIStackView()
    
    init(option: ImagePollBlock.ImagePoll.Option) {
        fillBar = PollOptionFillBar(color: option.resultFillColor)
        super.init(frame: .zero)
        
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // stackView
        
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
        
        // label
        
        label.heightAnchor.constraint(equalToConstant: 24).isActive = true
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(label)
        
        // fillBar
        
        fillBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        fillBar.layer.cornerRadius = 4
        fillBar.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        stackView.addArrangedSubview(fillBar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

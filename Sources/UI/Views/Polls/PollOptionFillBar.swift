//
//  PollOptionFillBar.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class PollOptionFillBar: UIView {
    let fillView = UIView()
    var widthConstraint: NSLayoutConstraint!
    
    init(color: Color) {
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

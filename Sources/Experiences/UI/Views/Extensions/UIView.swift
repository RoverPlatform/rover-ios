//
//  UIView.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

extension UIView {
    func configureOpacity(opacity: Double?) {
        self.alpha = opacity.map { CGFloat($0) } ?? 0.0
    }
    
    func configureBorder(border: Border?, constrainedByFrame frame: CGRect?) {
        guard let border = border else {
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
            layer.cornerRadius = 0
            return
        }
        
        layer.borderColor = border.color.uiColor.cgColor
        layer.borderWidth = CGFloat(border.width)
        layer.cornerRadius = {
            let radius = CGFloat(border.radius)
            guard let frame = frame else {
                return radius
            }
            let maxRadius = min(frame.height, frame.width) / 2
            return min(radius, maxRadius)
        }()
    }
    
    func configureBackgroundColor(color: Color?, opacity: Double?) {
        guard let color = color, let opacity = opacity else {
            backgroundColor = UIColor.clear
            return
        }
        
        self.backgroundColor = color.uiColor(dimmedBy: opacity)
    }
    
    func configureContent(content: UIView, withInsets insets: Insets) {
        NSLayoutConstraint.deactivate(self.constraints)
        self.removeConstraints(self.constraints)
        
        let insets: UIEdgeInsets = {
            let top = CGFloat(insets.top)
            let left = CGFloat(insets.left)
            let bottom = 0 - CGFloat(insets.bottom)
            let right = 0 - CGFloat(insets.right)
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }()
        
        content.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: insets.bottom).isActive = true
        content.leftAnchor.constraint(equalTo: self.leftAnchor, constant: insets.left).isActive = true
        content.rightAnchor.constraint(equalTo: self.rightAnchor, constant: insets.right).isActive = true
        content.topAnchor.constraint(equalTo: self.topAnchor, constant: insets.top).isActive = true
    }
}

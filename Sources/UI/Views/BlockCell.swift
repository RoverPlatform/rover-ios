//
//  BlockCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class BlockCell: UICollectionViewCell {
    var block: Block?
    
    var content: UIView? {
        return nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    func configure(with block: Block) {
        self.block = block
        
        configureBackgroundColor()
        configureBackgroundImage()
        configureBorder()
        configureOpacity()
        configureContent()
    }
    
    func configureBackgroundColor() {
        self.configureBackgroundColor(color: block?.background.color, opacity: block?.opacity)
    }
    
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    func configureBackgroundImage() {
        guard let backgroundImageView = backgroundView as? UIImageView else {
            return
        }
        
        let originalBlockId = block?.id
        backgroundImageView.configureAsBackgroundImage(background: block?.background) { [weak self] in
            // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
            return self?.block?.id == originalBlockId
        }
    }
    
    func configureBorder() {
        self.configureBorder(border: block?.border, constrainedByFrame: self.frame)
    }
    
    func configureOpacity() {
        self.contentView.configureOpacity(opacity: block?.opacity)
    }
    
    func configureContent() {
        guard let block = block, let content = content else {
            return
        }
        
        self.contentView.configureContent(content: content, withInsets: block.insets)
    }
}

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

extension UIImageView {
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    func configureAsBackgroundImage(background: Background?, checkStillMatches: @escaping () -> Bool) {
        // Reset any existing background image
        
        self.alpha = 0.0
        self.image = nil
        
        // Background color is used for tiled backgrounds
        self.backgroundColor = UIColor.clear
        
        guard let background = background else {
            return
        }
        
        switch background.contentMode {
        case .fill:
            self.contentMode = .scaleAspectFill
        case .fit:
            self.contentMode = .scaleAspectFit
        case .original:
            self.contentMode = .center
        case .stretch:
            self.contentMode = .scaleToFill
        case .tile:
            self.contentMode = .center
        }
        
        if let image = ImageStore.shared.image(for: background, frame: frame) {
            if case .tile = background.contentMode {
                self.backgroundColor = UIColor(patternImage: image)
            } else {
                self.image = image
            }
            self.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: background, frame: frame) { [weak self] image in
                guard let image = image, checkStillMatches() else {
                    return
                }
                
                if case .tile = background.contentMode {
                    self?.backgroundColor = UIColor(patternImage: image)
                } else {
                    self?.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}

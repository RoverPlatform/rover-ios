//
//  BlockCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class BlockCell: UICollectionViewCell {
    public var block: Block?
    
    open var content: UIView? {
        return nil
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    open func configure(with block: Block) {
        self.block = block
        
        configureBackgroundColor()
        configureBackgroundImage()
        configureBorder()
        configureOpacity()
        configureContent()
    }
    
    open func configureBackgroundColor() {
        guard let block = block else {
            backgroundColor = UIColor.clear
            return
        }
        
        backgroundColor = block.background.color.uiColor(dimmedBy: block.opacity)
    }
    
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    open func configureBackgroundImage() {
        guard let backgroundImageView = backgroundView as? UIImageView else {
            return
        }
        
        // Reset any existing background image
        
        backgroundImageView.alpha = 0.0
        backgroundImageView.image = nil
        
        // Background color is used for tiled backgrounds
        backgroundImageView.backgroundColor = UIColor.clear
        
        guard let block = block else {
            return
        }
        
        switch block.background.contentMode {
        case .fill:
            backgroundImageView.contentMode = .scaleAspectFill
        case .fit:
            backgroundImageView.contentMode = .scaleAspectFit
        case .original:
            backgroundImageView.contentMode = .center
        case .stretch:
            backgroundImageView.contentMode = .scaleToFill
        case .tile:
            backgroundImageView.contentMode = .center
        }
        
        if let image = ImageStore.shared.image(for: block.background, frame: frame) {
            if case .tile = block.background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: block.background, frame: frame) { [weak self, weak backgroundImageView, blockID = block.id] image in
                guard let image = image else {
                    return
                }
                
                // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
                
                if self?.block?.id != blockID {
                    return
                }
                
                if case .tile = block.background.contentMode {
                    backgroundImageView?.backgroundColor = UIColor(patternImage: image)
                } else {
                    backgroundImageView?.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    backgroundImageView?.alpha = 1.0
                }
            }
        }
    }
    
    open func configureBorder() {
        guard let block = block else {
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
            layer.cornerRadius = 0
            return
        }
        
        let border = block.border
        layer.borderColor = border.color.uiColor.cgColor
        layer.borderWidth = CGFloat(border.width)
        layer.cornerRadius = {
            let radius = CGFloat(border.radius)
            let maxRadius = min(frame.height, frame.width) / 2
            return min(radius, maxRadius)
        }()
    }
    
    open func configureOpacity() {
        guard let block = block else {
            layer.opacity = 0
            return
        }
        
        self.contentView.alpha = CGFloat(block.opacity)
    }
    
    open func configureContent() {
        guard let block = block, let content = content else {
            return
        }
        
        NSLayoutConstraint.deactivate(contentView.constraints)
        contentView.removeConstraints(contentView.constraints)

        let insets: UIEdgeInsets = {
            let top = CGFloat(block.insets.top)
            let left = CGFloat(block.insets.left)
            let bottom = 0 - CGFloat(block.insets.bottom)
            let right = 0 - CGFloat(block.insets.right)
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }()
        
        content.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: insets.bottom).isActive = true
        content.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: insets.left).isActive = true
        content.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: insets.right).isActive = true
        content.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: insets.top).isActive = true
    }
}

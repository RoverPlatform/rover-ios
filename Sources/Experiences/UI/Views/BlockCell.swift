//
//  BlockCell.swift
//  RoverExperiences
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
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        backgroundView = UIImageView()
        clipsToBounds = true
        
        if let content = content {
            contentView.addSubview(content)
        }
    }
    
    open func configure(with block: Block, imageStore: ImageStore) {
        self.block = block
        
        configureBackgroundColor()
        configureBackgroundImage(imageStore: imageStore)
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
    
    open func configureBackgroundImage(imageStore: ImageStore) {
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
        
        guard let configuration = ImageConfiguration(background: block.background, frame: frame) else {
            return
        }
        
        if let image = imageStore.fetchedImage(for: configuration) {
            if case .tile = block.background.contentMode {
                backgroundImageView.backgroundColor = UIColor(patternImage: image)
            } else {
                backgroundImageView.image = image
            }
            backgroundImageView.alpha = 1.0
        } else {
            imageStore.fetchImage(for: configuration) { [weak self, weak backgroundImageView, blockID = block.id] image in
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
                
                UIView.animate(withDuration: 0.25, animations: {
                    backgroundImageView?.alpha = 1.0
                })
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
        guard let block = block, let contentView = content else {
            return
        }
        
        let insets: UIEdgeInsets = {
            let top = CGFloat(block.insets.top)
            let left = CGFloat(block.insets.left)
            let bottom = 0 - CGFloat(block.insets.bottom)
            let right = 0 - CGFloat(block.insets.right)
            return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }()
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: insets.bottom).isActive = true
        contentView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: insets.left).isActive = true
        contentView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: insets.right).isActive = true
        contentView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: insets.top).isActive = true
    }
}

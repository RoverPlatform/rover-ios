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
        configureA11yTraits()
    }
    
    func configureBackgroundColor() {
        self.configureBackgroundColor(color: block?.background.color, opacity: block?.opacity)
    }
    
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
    
    func configureA11yTraits() {
        guard let block = block else {
            return
        }
        
        // if no inner content, then apply the a11y traits to the cell itself.
        let view = content ?? self
        
        guard !(block is TextPollBlock), !(block is ImagePollBlock), !(block is WebViewBlock) else {
            // Polls and webviews implement their own a11y.
            return
        }
        
        // Some Rover blocks do not currently have a11y alternative descriptions available.
        let hasContent = !(block is ImageBlock) && !(block is RectangleBlock)
        
        // All Rover blocks that have meaningful content should be a11y, or if they at least have tap behaviour.
        view.isAccessibilityElement = hasContent || block.tapBehavior != .none
        
        // tapbehaviour be mapped to the `link` a11y trait:
        switch block.tapBehavior {
        case .goToScreen(_), .openURL(_, _), .presentWebsite(_):
            view.accessibilityTraits.applyTrait(trait: .link, to: true)
        default:
            view.accessibilityTraits.applyTrait(trait: .link, to: false)
        }
    }
}

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
    
    func configure(with block: Block, for experience: Experience) {
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

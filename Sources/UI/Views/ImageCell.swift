//
//  ImageCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class ImageCell: BlockCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    override var content: UIView? {
        return imageView
    }
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let imageBlock = block as? ImageBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.alpha = 0.0
        imageView.image = nil
        
        if let image = ImageStore.shared.image(for: imageBlock.image, frame: frame) {
            imageView.image = image
            imageView.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: imageBlock.image, frame: frame) { [weak self, blockID = block.id] image in
                guard let image = image else {
                    return
                }
                
                // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
                
                if self?.block?.id != blockID {
                    return
                }
                
                self?.imageView.image = image
                
                UIView.animate(withDuration: 0.25) {
                    self?.imageView.alpha = 1.0
                }
            }
        }
    }
}

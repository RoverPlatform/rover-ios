//
//  ImageCell.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class ImageCell: BlockCell {
    public let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    open override var content: UIView? {
        return imageView
    }
    
    open override func configure(with block: Block, imageStore: ImageStore) {
        super.configure(with: block, imageStore: imageStore)
        
        guard let imageBlock = block as? ImageBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.alpha = 0.0
        imageView.image = nil
        
        let configuration = ImageConfiguration(image: imageBlock.image, frame: frame)
        if let image = imageStore.fetchedImage(for: configuration) {
            imageView.image = image
            imageView.alpha = 1.0
        } else {
            imageStore.fetchImage(for: configuration) { [weak self, blockID = block.id] image in
                guard let image = image else {
                    return
                }
                
                // Verify the block cell is still configured to the same block; otherwise we should no-op because the cell has been recycled.
                
                if self?.block?.id != blockID {
                    return
                }
                
                self?.imageView.image = image
                
                UIView.animate(withDuration: 0.25, animations: {
                    self?.imageView.alpha = 1.0
                })
            }
        }
    }
}

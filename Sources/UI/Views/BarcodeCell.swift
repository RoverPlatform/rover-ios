//
//  BarcodeCell.swift
//  Rover
//
//  Created by Sean Rucker on 2018-04-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class BarcodeCell: BlockCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()

        // Using stretch fit because we've ensured that the image will scale aspect-correct, so will always have the
        // correct aspect ratio (because auto-height will be always on), and we also are using integer scaling to ensure
        // a sharp scale of the pixels.  While we could use .scaleToFit, .scaleToFill will avoid the barcode
        // leaving any unexpected gaps around the outside in case of lack of agreement.
        imageView.contentMode = .scaleToFill
        
        imageView.accessibilityLabel = "Barcode"
        
        #if swift(>=4.2)
        imageView.layer.magnificationFilter = CALayerContentsFilter.nearest
        #else
        imageView.layer.magnificationFilter = kCAFilterNearest
        #endif
        
        return imageView
    }()
    
    override var content: UIView? {
        return imageView
    }
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let barcodeBlock = block as? BarcodeBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.isHidden = false
        imageView.image = nil

        let barcode = barcodeBlock.barcode

        guard let barcodeImage = barcode.cgImage else {
            imageView.image = nil
            return
        }

        imageView.image = UIImage(cgImage: barcodeImage)
    }
}

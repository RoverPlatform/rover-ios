//
//  BarcodeCell.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-04-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

open class BarcodeCell: BlockCell {
    open let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    open override var content: UIView? {
        return imageView
    }
    
    open override func configure(with block: Block, imageStore: ImageStore) {
        super.configure(with: block, imageStore: imageStore)
        
        guard let barcodeBlock = block as? BarcodeBlock else {
            imageView.isHidden = true
            return
        }
        
        imageView.isHidden = false
        imageView.image = nil
        
        let barcode = barcodeBlock.barcode
        
        guard let data = barcode.text.data(using: String.Encoding.ascii) else {
            return
        }
        
        let filterName: String
        switch barcode.format {
        case .aztecCode:
            filterName = "CIAztecCodeGenerator"
        case .code128:
            filterName = "CICode128BarcodeGenerator"
        case .pdf417:
            filterName = "CIPDF417BarcodeGenerator"
        case .qrCode:
            filterName = "CIQRCodeGenerator"
        }
        
        let filter = CIFilter(name: filterName)!
        filter.setDefaults()
        filter.setValue(data, forKey: "inputMessage")
        
        let scale = CGFloat(barcode.scale)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        guard let outputImage = filter.outputImage?.transformed(by: transform) else {
            return
        }
        
        let context = CIContext.init(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return
        }
        
        imageView.image = UIImage.init(cgImage: cgImage)
    }
}

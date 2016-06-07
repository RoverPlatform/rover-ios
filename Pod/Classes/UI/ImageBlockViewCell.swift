//
//  ImageBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-06.
//
//

import UIKit

class ImageBlockViewCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        imageView.contentMode = .ScaleToFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        contentView.addConstraints([
            NSLayoutConstraint(item: imageView, attribute: .Leading, relatedBy: .Equal, toItem: contentView, attribute: .Leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: imageView, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: imageView, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: imageView, attribute: .Bottom, relatedBy: .Equal, toItem: contentView, attribute: .Bottom, multiplier: 1, constant: 0)
            ])
    }
}

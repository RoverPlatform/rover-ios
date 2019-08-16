//
//  ImagePollOptionImage.swift
//  Rover
//
//  Created by Sean Rucker on 2019-08-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class ImagePollOptionImage: UIImageView {
    let option: ImagePollBlock.ImagePoll.Option
    
    init(option: ImagePollBlock.ImagePoll.Option) {
        self.option = option
        super.init(frame: .zero)
        
        contentMode = .scaleAspectFill
        heightAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.alpha = 0.0
        self.image = nil
    
        if let image = ImageStore.shared.image(for: option.image, filledInFrame: self.frame) {
            self.image = image
            self.alpha = 1.0
        } else {
            let originalFrame = self.frame
            ImageStore.shared.fetchImage(for: option.image, filledInFrame: self.frame) { [weak self] image in
                guard let image = image, self?.frame == originalFrame else {
                    return
                }
                
                self?.image = image
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}

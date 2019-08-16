//
//  UIImageView.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

extension UIImageView {
    // swiftlint:disable:next cyclomatic_complexity // This routine is fairly readable as it is, so we will hold off on refactoring it, so silence the complexity warning.
    func configureAsBackgroundImage(background: Background?, checkStillMatches: @escaping () -> Bool = { true }) {
        // Reset any existing background image
        
        self.alpha = 0.0
        self.image = nil
        
        // Background color is used for tiled backgrounds
        self.backgroundColor = UIColor.clear
        
        guard let background = background else {
            return
        }
        
        switch background.contentMode {
        case .fill:
            self.contentMode = .scaleAspectFill
        case .fit:
            self.contentMode = .scaleAspectFit
        case .original:
            self.contentMode = .center
        case .stretch:
            self.contentMode = .scaleToFill
        case .tile:
            self.contentMode = .center
        }
        
        if let image = ImageStore.shared.image(for: background, frame: frame) {
            if case .tile = background.contentMode {
                self.backgroundColor = UIColor(patternImage: image)
            } else {
                self.image = image
            }
            self.alpha = 1.0
        } else {
            let originalFrame = self.frame
            ImageStore.shared.fetchImage(for: background, frame: frame) { [weak self] image in
                guard let image = image, checkStillMatches(), self?.frame == originalFrame else {
                    return
                }
                
                if case .tile = background.contentMode {
                    self?.backgroundColor = UIColor(patternImage: image)
                } else {
                    self?.image = image
                }
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}

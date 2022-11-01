//
//  UIAccessibilityTraits+mutation.swift
//  Rover
//
//  Created by Andrew Clunis on 2020-04-03.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

import UIKit

extension UIAccessibilityTraits {
    mutating func applyTrait(trait: UIAccessibilityTraits, to: Bool) {
        if to {
            // set the bit to 1.
            self = UIAccessibilityTraits(rawValue: self.rawValue | trait.rawValue)
        } else {
            // set the bit to 0
            self = UIAccessibilityTraits(rawValue: self.rawValue & ~trait.rawValue)
        }
    }
}

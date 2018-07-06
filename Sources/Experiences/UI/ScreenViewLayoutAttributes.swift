//
//  ScreenViewLayoutAttributes.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-04-18.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class ScreenLayoutAttributes: UICollectionViewLayoutAttributes {
    var referenceFrame = CGRect.zero
    var verticalAlignment = UIControlContentVerticalAlignment.top
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone)
        
        guard let attributes = copy as? ScreenLayoutAttributes else {
            return copy
        }
        
        attributes.referenceFrame = referenceFrame
        attributes.verticalAlignment = verticalAlignment
        return attributes
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ScreenLayoutAttributes else {
            return false
        }
        
        return super.isEqual(object) && referenceFrame == rhs.referenceFrame && verticalAlignment == rhs.verticalAlignment
    }
}

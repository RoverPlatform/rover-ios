//
//  ScreenViewLayoutAttributes.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-04-18.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class ScreenLayoutAttributes: UICollectionViewLayoutAttributes {
    /**
     * Where in absolute space (both position and dimensions) for the entire screen view controller
     * this item should be placed.
     */
    var referenceFrame = CGRect.zero
    
    var verticalAlignment = UIControlContentVerticalAlignment.top
    
    /**
     * An optional clip area, in the coordinate space of the block view itself (ie., top left of the view
     * is origin).
     */
    var clipRect: CGRect? = CGRect.zero
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone)
        
        guard let attributes = copy as? ScreenLayoutAttributes else {
            return copy
        }
        
        attributes.referenceFrame = referenceFrame
        attributes.verticalAlignment = verticalAlignment
        attributes.clipRect = clipRect
        return attributes
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ScreenLayoutAttributes else {
            return false
        }
        
        return super.isEqual(object) && referenceFrame == rhs.referenceFrame && verticalAlignment == rhs.verticalAlignment && clipRect == rhs.clipRect
    }
}

// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit

class ScreenLayoutAttributes: UICollectionViewLayoutAttributes {
    /**
     * Where in absolute space (both position and dimensions) for the entire screen view controller
     * this item should be placed.
     */
    var referenceFrame = CGRect.zero
    var verticalAlignment = UIControl.ContentVerticalAlignment.top
        
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

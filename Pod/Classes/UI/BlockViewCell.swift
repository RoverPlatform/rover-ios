//
//  BlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-12.
//
//

import Foundation

@objc protocol BlockViewCellDelegate: class {
    optional func blockViewCellDidPressButton(cell: BlockViewCell)
}

class BlockViewCell: UICollectionViewCell {
    weak var delegate: BlockViewCellDelegate?
    
    var inset = UIEdgeInsetsZero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.gestureRecognized(_:)))
        longPressRecognizer.minimumPressDuration = 0
        longPressRecognizer.delegate = self
        self.contentView.addGestureRecognizer(longPressRecognizer)
        
        clipsToBounds = true
    }
    
    func didTouchDown() {
        
    }
    
    func didEndTouch() {
        
    }
    
    func didCancelTouch() {
        
    }
    
    func gestureRecognized(recognizer: UILongPressGestureRecognizer) {
        
        struct Static {
            static var touchCancelled = false
            static var location = CGPointZero
        }
        
        switch recognizer.state {
        case .Began:
            Static.touchCancelled = false
            Static.location = recognizer.locationInView(self.window)
            didTouchDown()
        case .Ended:
            if !Static.touchCancelled {
                delegate?.blockViewCellDidPressButton?(self)
                Static.touchCancelled = true
            }
            didEndTouch()
        default:
            // iPhone 6S sensitivity
            let newLocation = recognizer.locationInView(self.window)
            let dx = newLocation.x - Static.location.x
            let dy = newLocation.y - Static.location.y
            let distance = dx*dx + dy*dy
            
            if distance > 20 {
                Static.touchCancelled = true
                didCancelTouch()
            }
        }
    }
}

extension BlockViewCell : UIGestureRecognizerDelegate {
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
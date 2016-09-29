//
//  BlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-12.
//
//

import Foundation

@objc protocol BlockViewCellDelegate: class {
    @objc optional func blockViewCellDidPressButton(_ cell: BlockViewCell)
}

class BlockViewCell: UICollectionViewCell {
    weak var delegate: BlockViewCellDelegate?
    
    var inset = UIEdgeInsets.zero
    
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
    
    func gestureRecognized(_ recognizer: UILongPressGestureRecognizer) {
        
        struct Static {
            static var touchCancelled = false
            static var location = CGPoint.zero
        }
        
        switch recognizer.state {
        case .began:
            Static.touchCancelled = false
            Static.location = recognizer.location(in: self.window)
            didTouchDown()
        case .ended:
            if !Static.touchCancelled {
                delegate?.blockViewCellDidPressButton?(self)
                Static.touchCancelled = true
            }
            didEndTouch()
        default:
            // iPhone 6S sensitivity
            let newLocation = recognizer.location(in: self.window)
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
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
